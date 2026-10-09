import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/forms/forms.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../../domain/usecases/gerer_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/champ_quantite.dart';
import '../widgets/choix_contact.dart';
import '../widgets/choix_produit.dart';
import '../widgets/commerce_widgets.dart';

/// Achat chez un fournisseur : plusieurs produits, prix d'achat proposés,
/// produits habituels du fournisseur en premier.
class AchatFormPage extends ConsumerWidget {
  const AchatFormPage({super.key, this.achatId, this.fournisseurId, this.produitId});
  final String? achatId;
  final String? fournisseurId;
  final String? produitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider);
    return switch (etat) {
      AsyncData(value: final e) when achatId == null =>
        _Formulaire(etat: e, fournisseurId: fournisseurId, produitId: produitId),
      AsyncData(value: final e) when e.achat(achatId!) != null => _Formulaire(etat: e, initial: e.achat(achatId!)),
      AsyncData() => Scaffold(appBar: AppBar(), body: EmptyView(message: context.l10n.errorNotFound)),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.etat, this.initial, this.fournisseurId, this.produitId});
  final EtatCommerce etat;
  final Achat? initial;
  final String? fournisseurId;
  final String? produitId;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  final _formController = SmartFormController(initialOpenIndex: 0);

  late String? _fournisseurId = widget.initial?.fournisseurId ?? widget.fournisseurId;
  String? _boutique;
  late DateTime _date = widget.initial?.dateAchat ?? DateTime.now();
  late final _reference = TextEditingController(text: widget.initial?.reference);
  late final _note = TextEditingController(text: widget.initial?.note);
  late final List<LigneOperation> _lignes = [...?widget.initial?.lignes];
  bool _enCours = false;
  bool _aEteModifie = false;

  bool get _creation => widget.initial == null;

  @override
  void initState() {
    super.initState();
    final autorisees = ref.read(droitsCommerceProvider).boutiquesAchat;
    final courante = ref.read(boutiqueCouranteProvider);
    _boutique = widget.initial?.perimetreId ?? (autorisees.contains(courante) ? courante : autorisees.firstOrNull);
    if (widget.produitId case final id?) {
      if (widget.etat.produit(id) case final p?) _lignes.add(_nouvelleLigne(p));
    }

    for (final c in [_reference, _note]) {
      c.addListener(() {
        if (!_aEteModifie) setState(() => _aEteModifie = true);
      });
    }
  }

  @override
  void dispose() {
    _formController.dispose();
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Ligne proposée : la plus grande unité, au dernier prix d'achat connu.
  LigneOperation _nouvelleLigne(Produit p, {UniteVente? unite}) {
    final memo = ref.read(unitesMemoriseesProvider.notifier).pour('achat', p.id);
    final u = unite ?? p.unite(memo ?? p.plusGrandeUnite.id);
    final prix = widget.etat.dernierPrixAchat(p.id, u.nom) ?? u.prixAchat ?? 0;
    return LigneOperation(
      id: const Uuid().v4(),
      produitId: p.id,
      unite: u.nom,
      facteur: u.facteur,
      quantite: Qte.un,
      prixUnitaire: prix,
    );
  }

  Future<void> _ajouter() async {
    final etat = ref.read(etatCommerceProvider).value ?? widget.etat;
    final suggestions = _fournisseurId == null ? const <Produit>[] : etat.produitsDuFournisseur(_fournisseurId!);
    final p = await choisirProduit(
      context,
      suggestions: suggestions,
      onCreer: ref.read(droitsCommerceProvider).creerProduits ? () => context.push(Routes.produitNouveau()) : null,
    );
    if (p == null || !mounted) return;
    final ligne = await _editerLigne(p, _nouvelleLigne(p));
    if (ligne != null) {
      setState(() {
        _lignes.add(ligne);
        _aEteModifie = true;
      });
    }
  }

  Future<LigneOperation?> _editerLigne(Produit p, LigneOperation ligne) =>
      showModalBottomSheet<LigneOperation>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _EditeurLigne(produit: p, ligne: ligne, etat: widget.etat),
      );

  // --- Statuts et Résumés dynamiques des sections ---
  FormSectionStatus get _fournisseurStatus {
    if (_fournisseurId != null || _boutique != null) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  String _fournisseurSummary(AppLocalizations l10n) {
    final elements = [
      nomContact(ref, _fournisseurId) ?? 'Fournisseur non sélectionné',
      l10n.date(_date),
      if (_reference.text.trim().isNotEmpty) 'Réf: ${_reference.text.trim()}',
    ];
    return elements.join(' • ');
  }

  FormSectionStatus get _lignesStatus {
    if (_lignes.isEmpty) return FormSectionStatus.emptyRequired;
    return FormSectionStatus.complete;
  }

  String _lignesSummary(AppLocalizations l10n) {
    if (_lignes.isEmpty) return 'Aucun article ajouté (Requis)';
    final count = _lignes.length;
    final total = totalLignes(_lignes);
    return '$count article${count > 1 ? 's' : ''} • ${montant(context, ref, total)}';
  }

  FormSectionStatus get _noteStatus {
    if (_note.text.trim().isNotEmpty) return FormSectionStatus.complete;
    return FormSectionStatus.emptyOptional;
  }

  Future<void> _enregistrer({required bool recevoir}) async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null || _boutique == null) return;
    if (_lignes.isEmpty) {
      _formController.scrollToSection(1);
      return;
    }
    setState(() => _enCours = true);
    final saisie = SaisieAchat(
      perimetreId: _boutique!,
      fournisseurId: _fournisseurId,
      reference: _reference.text,
      date: _date,
      lignes: _lignes,
      note: _note.text,
    );
    final gerer = ref.read(gererCommerceProvider);
    try {
      for (final l in _lignes) {
        ref.read(unitesMemoriseesProvider.notifier).retenir('achat', l.produitId, etat.produit(l.produitId)!.uniteNommee(l.unite).id);
      }
      if (_creation) {
        final achat = await gerer.creerAchat(ctx, etat, saisie, recevoirTout: recevoir);
        if (!mounted) return;
        _aEteModifie = false;
        confirmer(context, recevoir ? l10n.comReceptionDone : l10n.comPurchaseSaved);
        context.pushReplacement(Routes.achat(achat.id));
      } else {
        await gerer.modifierAchat(ctx, etat, widget.initial!, saisie);
        if (!mounted) return;
        _aEteModifie = false;
        confirmer(context, l10n.comPurchaseSaved);
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value ?? widget.etat;
    final droits = ref.watch(droitsCommerceProvider);
    final total = totalLignes(_lignes);
    final habituels = _fournisseurId == null
        ? const <Produit>[]
        : etat.produitsDuFournisseur(_fournisseurId!).where((p) => !_lignes.any((l) => l.produitId == p.id)).toList();
    final peutRecevoir = _creation && _boutique != null && droits.boutiquesReception.contains(_boutique);
    final valide = _lignes.isNotEmpty && _boutique != null && !_enCours;

    return UnsavedChangesScope(
      hasUnsavedChanges: _aEteModifie && !_enCours,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(_creation ? l10n.comNewPurchase : l10n.comEditPurchase)),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SmartFormContainer(
                  controller: _formController,
                  children: [
                    // Section 1 : Fournisseur & Contexte
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(0),
                      title: 'Fournisseur & Date d\'achat',
                      icon: Icons.local_shipping_rounded,
                      summary: _fournisseurSummary(l10n),
                      status: _fournisseurStatus,
                      isExpanded: _formController.isSectionOpen(0),
                      onToggle: () => setState(() => _formController.toggleSection(0)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 0,
                            color: AppColors.background,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              key: const Key('achat-fournisseur'),
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.greenSoft,
                                child: Icon(Icons.business_rounded, color: AppColors.green, size: 20),
                              ),
                              title: Text(l10n.comSupplier, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                              subtitle: Text(
                                nomContact(ref, _fournisseurId) ?? l10n.comNoSupplierChosen,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.ink),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              onTap: () async {
                                final c = await choisirContact(context, RelationContact.fournisseur);
                                if (c != null) {
                                  setState(() {
                                    _fournisseurId = c.id;
                                    _aEteModifie = true;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (droits.boutiquesAchat.length > 1 && _creation) ...[
                            ChampBoutique(
                              valeur: _boutique,
                              autorisees: droits.boutiquesAchat,
                              onChanged: (v) => setState(() {
                                _boutique = v;
                                _aEteModifie = true;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _date,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(const Duration(days: 1)),
                                    );
                                    if (d != null) {
                                      setState(() {
                                        _date = d;
                                        _aEteModifie = true;
                                      });
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: l10n.comPurchaseDate,
                                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                                    ),
                                    child: Text(l10n.date(_date)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: TextField(
                                  controller: _reference,
                                  decoration: InputDecoration(
                                    labelText: l10n.comSupplierReference,
                                    prefixIcon: const Icon(Icons.tag_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Section 2 : Articles & Produits commandés
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(1),
                      title: 'Articles commandés',
                      icon: Icons.inventory_2_rounded,
                      summary: _lignesSummary(l10n),
                      status: _lignesStatus,
                      isRequired: true,
                      isExpanded: _formController.isSectionOpen(1),
                      onToggle: () => setState(() => _formController.toggleSection(1)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (habituels.isNotEmpty) ...[
                            Text(
                              l10n.comUsualProducts,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.muted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            SizedBox(
                              height: 104,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  for (final p in habituels)
                                    Padding(
                                      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () async {
                                          final l = await _editerLigne(p, _nouvelleLigne(p));
                                          if (l != null) {
                                            setState(() {
                                              _lignes.add(l);
                                              _aEteModifie = true;
                                            });
                                          }
                                        },
                                        child: SizedBox(
                                          width: 76,
                                          child: Column(
                                            children: [
                                              ProduitImage(produit: p, taille: 64),
                                              const SizedBox(height: 4),
                                              Text(
                                                p.nom,
                                                maxLines: 2,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          for (final (i, l) in _lignes.indexed)
                            if (etat.produit(l.produitId) case final p?)
                              Card(
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: ListTile(
                                  key: Key('ligne-$i'),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  leading: ProduitImage(produit: p, taille: 48),
                                  title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    '${qteUnite(context, l.quantite, l.unite)} × ${montant(context, ref, l.prixUnitaire)}'
                                    '${l.facteur == Qte.un ? '' : '\n${equivalentBase(context, p, l.quantiteBase) ?? ''}'}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        montant(context, ref, l.montant),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.muted),
                                        onPressed: () => setState(() {
                                          _lignes.removeAt(i);
                                          _aEteModifie = true;
                                        }),
                                      ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final r = await _editerLigne(p, l);
                                    if (r != null) {
                                      setState(() {
                                        _lignes[i] = r;
                                        _aEteModifie = true;
                                      });
                                    }
                                  },
                                ),
                              ),
                          const SizedBox(height: 4),
                          FilledButton.tonalIcon(
                            key: const Key('achat-ajouter-ligne'),
                            onPressed: _ajouter,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(l10n.comAddLine),
                          ),
                        ],
                      ),
                    ),

                    // Section 3 : Note interne (Facultatif)
                    CollapsibleFormSection(
                      key: _formController.registerSectionKey(2),
                      title: 'Note & Observations',
                      icon: Icons.note_alt_rounded,
                      summary: _note.text.trim().isEmpty ? 'Aucune observation (Facultatif)' : _note.text.trim(),
                      status: _noteStatus,
                      isExpanded: _formController.isSectionOpen(2),
                      onToggle: () => setState(() => _formController.toggleSection(2)),
                      child: TextField(
                        controller: _note,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: l10n.comNoteOptional,
                          hintText: 'Instructions de livraison, remarques...',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Barre d'actions fixe avec récapitulatif total
              StickyFormActions(
                submitKey: const Key('achat-enregistrer'),
                onSubmit: valide ? () => _enregistrer(recevoir: false) : null,
                onCancel: () => Navigator.of(context).maybePop(),
                isLoading: _enCours,
                isSubmitDisabled: !valide,
                submitLabel: l10n.comSave,
                summaryWidget: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_lignes.length} article${_lignes.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 13),
                    ),
                    Row(
                      children: [
                        Text('${l10n.comTotal} : ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted)),
                        Text(
                          montant(context, ref, total),
                          key: const Key('achat-total'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF01226C)),
                        ),
                      ],
                    ),
                  ],
                ),
                trailingAction: peutRecevoir
                    ? FilledButton(
                        key: const Key('achat-enregistrer-recevoir'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.green,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: valide ? () => _enregistrer(recevoir: true) : null,
                        child: Text(l10n.comSaveAndReceive, style: const TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quantité, unité et prix d'achat d'une ligne.
class _EditeurLigne extends ConsumerStatefulWidget {
  const _EditeurLigne({required this.produit, required this.ligne, required this.etat});
  final Produit produit;
  final LigneOperation ligne;
  final EtatCommerce etat;

  @override
  ConsumerState<_EditeurLigne> createState() => _EditeurLigneState();
}

class _EditeurLigneState extends ConsumerState<_EditeurLigne> {
  late Qte? _quantite = widget.ligne.quantite;
  late UniteVente _unite = widget.produit.uniteNommee(widget.ligne.unite);
  late final _prix = TextEditingController(text: '${widget.ligne.prixUnitaire}');

  @override
  void dispose() {
    _prix.dispose();
    super.dispose();
  }

  void _changerUnite(UniteVente u) {
    if (u.id == _unite.id) return;
    final dernier = widget.etat.dernierPrixAchat(widget.produit.id, u.nom) ?? u.prixAchat;
    setState(() {
      _unite = u;
      if (dernier != null) _prix.text = '$dernier';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.produit;
    final prix = int.tryParse(_prix.text) ?? 0;
    final q = _quantite;
    final dernier = widget.etat.dernierPrixAchat(p.id, _unite.nom);
    final valide = q != null && q.estPositif && (p.venteFractionnee || q.fois(_unite.facteur).estEntier);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProduitImage(produit: p, taille: 52),
                const SizedBox(width: 12),
                Expanded(child: Text(p.nom, style: Theme.of(context).textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ChampQuantite(
              champKey: const Key('ligne-quantite'),
              produit: p,
              uniteInitiale: _unite,
              quantiteInitiale: widget.ligne.quantite,
              autofocus: true,
              onChanged: (q, u) {
                _changerUnite(u);
                setState(() => _quantite = q);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('ligne-prix'),
              controller: _prix,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: l10n.comUnitPrice(_unite.nom),
                helperText: dernier == null ? null : l10n.comLastPrice(montant(context, ref, dernier)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (q != null && q.estPositif) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(l10n.comTotal, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(montant(context, ref, q.montant(prix)),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('ligne-valider'),
              onPressed: valide
                  ? () => Navigator.pop(
                        context,
                        widget.ligne.copyWith(quantite: q, prixUnitaire: prix, unite: _unite.nom, facteur: _unite.facteur),
                      )
                  : null,
              child: Text(l10n.comApply),
            ),
          ],
        ),
      ),
    );
  }
}
