import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/sync/sync_models.dart';
import '../../../../core/utils/recherche.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../../domain/services/etat_commerce.dart';
import '../commerce_providers.dart';
import '../widgets/champ_quantite.dart';
import '../widgets/choix_contact.dart';
import '../widgets/commerce_widgets.dart';
import '../widgets/scanner.dart';

/// Création / modification d'un produit en deux étapes inspirées d'Ecomiq SaaS :
///   1. Le produit et ses unités (photos, nom, catégorie, unité de base, emballages) ;
///   2. Prix & Rentabilité, stock initial et options avancées.
class ProduitFormPage extends ConsumerWidget {
  const ProduitFormPage({super.key, this.produitId, this.codeBarres, this.categorieId});
  final String? produitId;
  final String? codeBarres;
  final String? categorieId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatCommerceProvider);
    return switch (etat) {
      AsyncData(value: final e) when produitId == null =>
        _Formulaire(etat: e, codeBarres: codeBarres, categorieId: categorieId),
      AsyncData(value: final e) => e.produit(produitId!) == null
          ? Scaffold(appBar: AppBar(), body: EmptyView(message: context.l10n.comProductNotFound))
          : _Formulaire(etat: e, initial: e.produit(produitId!)),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

// =============================================================================
// Saisies & Modèles Locaux
// =============================================================================

/// Un emballage en cours de saisie (« 1 carton contient 10 pièces »).
class _Emballage {
  _Emballage({required this.id, String nom = '', Qte? facteur})
      : nom = TextEditingController(text: nom),
        facteur = TextEditingController(text: facteur == null ? '' : _texteQte(facteur));

  final String id;
  final TextEditingController nom;
  final TextEditingController facteur;

  Qte? get facteurQte => Qte.lire(facteur.text);
  bool get valide => nom.text.trim().isNotEmpty && (facteurQte?.estPositif ?? false);

  void dispose() {
    nom.dispose();
    facteur.dispose();
  }
}

/// Un prix saisi dans une unité choisie (« 8 000 F par carton »).
class _PrixSaisi {
  _PrixSaisi({int? montant, this.uniteId = UniteVente.idBase})
      : montant = TextEditingController(text: montant?.toString() ?? '');

  final TextEditingController montant;
  String uniteId;

  int? get valeur => int.tryParse(montant.text.replaceAll(RegExp(r'[\s  ]'), ''));
}

String _texteQte(Qte q) => q.estEntier ? '${q.brut ~/ Qte.echelle}' : q.valeur.toString();

// =============================================================================
// Formulaire Principal
// =============================================================================

class _Formulaire extends ConsumerStatefulWidget {
  const _Formulaire({required this.etat, this.initial, this.codeBarres, this.categorieId});
  final EtatCommerce etat;
  final Produit? initial;
  final String? codeBarres;
  final String? categorieId;

  @override
  ConsumerState<_Formulaire> createState() => _FormulaireState();
}

class _FormulaireState extends ConsumerState<_Formulaire> {
  late final String _id = widget.initial?.id ?? const Uuid().v4();
  late final List<String> _photos = [...?widget.initial?.photos];
  late final _nom = TextEditingController(text: widget.initial?.nom);
  late final _reference = TextEditingController(text: widget.initial?.reference);
  late final _codeBarres = TextEditingController(text: widget.initial?.codeBarres ?? widget.codeBarres);
  late final _description = TextEditingController(text: widget.initial?.description);
  late String? _categorieId = widget.initial?.categorieId ?? widget.categorieId;
  late String _uniteBase = widget.initial?.uniteBase ?? '';
  late final List<_Emballage> _emballages = [
    for (final u in widget.initial?.unites ?? const <UniteProduit>[])
      _Emballage(id: u.id, nom: u.nom, facteur: u.facteur),
  ];
  late final _detail = _prixInitial((u) => u.prixDetail, widget.initial?.prixDetail);
  late final _gros = _prixInitial((u) => u.prixGros, widget.initial?.prixGros);
  late final _achat = _prixInitial((u) => u.prixAchat, widget.initial?.prixAchat);
  late bool _venteGros = widget.initial?.venteEnGros ?? (widget.initial == null && widget.etat.venteEnGros);

  String? _boutique;
  Qte? _stockInitial;
  UniteVente? _uniteStock;
  late Qte _seuil = widget.initial?.seuilAlerte ?? Qte.zero;
  late bool _fractionnee = widget.initial?.venteFractionnee ?? false;
  late Qte _pas = widget.initial?.pasMinimum ?? const Qte(2500);
  late final Map<String, TextEditingController> _attributs = {
    for (final MapEntry(:key, :value) in (widget.initial?.attributs ?? const <String, String>{}).entries)
      key: TextEditingController(text: value),
  };
  late String? _fournisseurId = widget.initial?.fournisseurId;
  int _etape = 0;
  bool _enCours = false;
  final _defilement = ScrollController();

  bool get _creation => widget.initial == null;

  /// Prix d'un produit existant : l'unité où le commerçant l'avait fixé, sinon la base.
  _PrixSaisi _prixInitial(int? Function(UniteProduit u) prixDe, int? prixBase) {
    final p = widget.initial;
    if (p != null) {
      for (final u in p.unites) {
        if (prixDe(u) case final fixe?) return _PrixSaisi(montant: fixe, uniteId: u.id);
      }
    }
    return _PrixSaisi(montant: p == null ? null : prixBase);
  }

  @override
  void initState() {
    super.initState();
    final droits = ref.read(droitsCommerceProvider);
    final courante = ref.read(boutiqueCouranteProvider);
    _boutique = droits.boutiquesEntreeSortie.contains(courante) ? courante : droits.boutiquesEntreeSortie.firstOrNull;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_uniteBase.isEmpty) _uniteBase = context.l10n.comUnitPiece;
  }

  @override
  void dispose() {
    for (final c in [_nom, _reference, _codeBarres, _description, _detail.montant, _gros.montant, _achat.montant]) {
      c.dispose();
    }
    for (final e in _emballages) {
      e.dispose();
    }
    for (final c in _attributs.values) {
      c.dispose();
    }
    _defilement.dispose();
    super.dispose();
  }

  bool get _etape1Valide => _nom.text.trim().isNotEmpty && _uniteBase.trim().isNotEmpty;

  /// Unités utilisables pour un prix : la base et les emballages complets.
  List<(String id, String nom, Qte facteur)> get _unitesChoisissables => [
        (UniteVente.idBase, _uniteBase, Qte.un),
        for (final e in _emballages)
          if (e.valide) (e.id, e.nom.text.trim(), e.facteurQte!),
      ];

  Qte _facteurDe(String id) =>
      _unitesChoisissables.where((u) => u.$1 == id).firstOrNull?.$3 ?? Qte.un;

  String _uniteValide(_PrixSaisi p) =>
      _unitesChoisissables.any((u) => u.$1 == p.uniteId) ? p.uniteId : UniteVente.idBase;

  /// Prix de l'unité de base déduit du prix saisi (8 000 F le carton de 10 → 800 F).
  int? _prixBase(_PrixSaisi p) {
    final v = p.valeur;
    if (v == null) return null;
    final id = _uniteValide(p);
    return id == UniteVente.idBase ? v : CalculPrix.base(v, _facteurDe(id));
  }

  /// Prix fixé pour un emballage : exactement le montant saisi, s'il l'a été dans cette unité.
  int? _prixFixe(_PrixSaisi p, _Emballage e) {
    final base = _prixBase(p);
    if (base == null || _uniteValide(p) != e.id) return null;
    return CalculPrix.aEnregistrer(p.valeur, base, e.facteurQte!);
  }

  Produit _produit() {
    final ctx = ref.read(contexteActifProvider)!;
    return Produit(
      id: _id,
      entrepriseId: widget.initial?.entrepriseId ?? ctx.entreprise!.id,
      categorieId: _categorieId,
      nom: _nom.text.trim(),
      reference: _reference.text.trim(),
      codeBarres: _codeBarres.text.trim(),
      description: _description.text.trim(),
      photos: _photos,
      uniteBase: _uniteBase.trim(),
      unites: [
        for (final e in _emballages)
          if (e.valide)
            UniteProduit(
              id: e.id,
              nom: e.nom.text.trim(),
              facteur: e.facteurQte!,
              prixDetail: _prixFixe(_detail, e),
              prixGros: _venteGros ? _prixFixe(_gros, e) : null,
              prixAchat: _prixFixe(_achat, e),
            ),
      ],
      prixDetail: _prixBase(_detail) ?? 0,
      prixGros: _venteGros ? _prixBase(_gros) : null,
      prixAchat: _prixBase(_achat),
      venteFractionnee: _fractionnee,
      pasMinimum: _pas,
      seuilAlerte: _seuil,
      attributs: {
        for (final MapEntry(:key, :value) in _attributs.entries)
          if (value.text.trim().isNotEmpty) key: value.text.trim(),
      },
      fournisseurId: _fournisseurId,
      estActif: widget.initial?.estActif ?? true,
      version: widget.initial?.version,
      syncStatus: widget.initial?.syncStatus ?? RecordSyncStatus.pendingSync,
    );
  }

  Future<void> _enregistrer() async {
    HapticFeedback.mediumImpact();
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    if (ctx == null || etat == null || !_etape1Valide) return;
    setState(() => _enCours = true);
    final gerer = ref.read(gererCommerceProvider);
    try {
      final produit = _produit();
      if (_creation) {
        await gerer.creerProduit(ctx, etat, produit,
            perimetreId: _boutique,
            stockInitial: _stockInitial ?? Qte.zero,
            uniteStock: _uniteStock == null ? null : produit.uniteNommee(_uniteStock!.nom),
            noteStockInitial: l10n.comInitialStockNote);
      } else {
        await gerer.modifierProduit(ctx, etat, widget.initial!, produit);
      }
      if (!mounted) return;
      confirmer(context, l10n.comProductSaved);
      if (_creation) {
        context.pushReplacement(Routes.produit(produit.id));
      } else {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  void _allerA(int etape) {
    HapticFeedback.lightImpact();
    setState(() => _etape = etape);
    if (_defilement.hasClients) _defilement.jumpTo(0);
  }

  // --- Photos -------------------------------------------------------------------

  Future<void> _ajouterPhoto(ImageSource source) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1024, imageQuality: 75);
      if (x == null) return;
      final chemin = await ref
          .read(photosProduitsProvider)
          .ajouter(entrepriseId: ctx.entreprise!.id, produitId: _id, octets: await x.readAsBytes());
      if (mounted) setState(() => _photos.add(chemin));
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _choisirSourcePhoto() async {
    final l10n = context.l10n;
    if (!ImagePicker().supportsImageSource(ImageSource.camera)) return _ajouterPhoto(ImageSource.gallery);
    HapticFeedback.mediumImpact();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(l10n.comTakePhoto, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
                ),
                title: Text(l10n.comTakePhoto, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4F46E5)),
                ),
                title: Text(l10n.comChooseFromGallery, style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _ajouterPhoto(source);
  }

  // --- Rendu ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etapes = [l10n.comStepProductUnits, l10n.comStepPricesStock];
    final derniere = _etape == etapes.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_creation ? l10n.comNewProduct : l10n.comEditProduct),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: _Progression(etapes: etapes, courante: _etape, onTap: (i) {
            if (i == 0 || _etape1Valide) _allerA(i);
          }),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _defilement,
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _etape == 0 ? _etapeProduit() : _etapePrixStock(),
                    ),
                  ),
                ),
              ),
            ),
            _BarreActions(
              children: [
                if (_etape > 0)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: () => _allerA(_etape - 1),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(l10n.comPrevious),
                  )
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    onPressed: () => context.pop(),
                    child: Text(l10n.commonCancel),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton.icon(
                    key: Key(derniere ? 'produit-enregistrer' : 'produit-suivant'),
                    onPressed: _enCours || !_etape1Valide
                        ? null
                        : derniere
                            ? _enregistrer
                            : () => _allerA(_etape + 1),
                    iconAlignment: derniere ? IconAlignment.start : IconAlignment.end,
                    icon: _enCours
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : Icon(derniere ? Icons.check_rounded : Icons.arrow_forward_rounded),
                    label: Text(derniere ? (_creation ? l10n.comSaveProduct : l10n.comSaveChanges) : l10n.comNext),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Étape 1 : Médias, Infos Générales & Emballages (Style Ecomiq SaaS)
  // ===========================================================================

  List<Widget> _etapeProduit() {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value ?? widget.etat;

    return [
      // 1. Zone Médias / Upload Box Moderne
      _Section(
        icone: Icons.add_photo_alternate_outlined,
        titre: 'Photos & Médias',
        aide: 'Ajoutez jusqu\'à 5 photos claires de votre produit.',
        action: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _photos.isEmpty ? AppColors.muted.withValues(alpha: 0.1) : AppColors.greenSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_photos.length}/5',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _photos.isEmpty ? AppColors.muted : AppColors.greenPressed,
            ),
          ),
        ),
        children: [
          _BoxUploadMedias(
            photos: _photos,
            produit: _produit(),
            onAjouter: _photos.length < 5 ? _choisirSourcePhoto : null,
            onRetirer: (i) => setState(() => _photos.removeAt(i)),
            onDefinirPrincipale: (i) {
              if (i == 0 || i >= _photos.length) return;
              setState(() {
                final photo = _photos.removeAt(i);
                _photos.insert(0, photo);
              });
            },
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // 2. Informations Générales
      _Section(
        icone: Icons.inventory_2_outlined,
        titre: l10n.comProductInfo,
        aide: l10n.comProductInfoHint,
        children: [
          _Libelle('${l10n.comProductName} *'),
          TextField(
            key: const Key('produit-nom'),
            controller: _nom,
            autofocus: _creation,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
            decoration: _decoration(
              hint: l10n.comProductNameHint,
              prefixe: const Icon(Icons.edit_note_rounded, color: AppColors.muted),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          _Libelle(l10n.comCategory),
          _ChoixCategorie(etat: etat, categorieId: _categorieId, onChanged: (c) => setState(() => _categorieId = c)),
          const SizedBox(height: AppSpacing.md),
          _Libelle(l10n.comBarcodeLabel),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('produit-code-barres'),
                  controller: _codeBarres,
                  decoration: _decoration(
                    hint: l10n.comBarcodeHint,
                    prefixe: const Icon(Icons.qr_code_2_rounded, color: AppColors.muted),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              BoutonScanner(boxed: true, onCode: (c) => setState(() => _codeBarres.text = c)),
            ],
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // 3. Unité de base (Comment comptez-vous)
      _Section(
        icone: Icons.straighten_rounded,
        titre: l10n.comHowCounted,
        aide: l10n.comHowCountedHint,
        children: [
          _ChoixUniteBase(
            valeur: _uniteBase,
            onChanged: (u) => setState(() => _uniteBase = u),
            onAutre: () async {
              final nom = await _demanderTexte(l10n.comUnitName, l10n.comUnitNameHint);
              if (nom != null) setState(() => _uniteBase = nom);
            },
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // 4. Emballages & Lots
      _Section(
        icone: Icons.inventory_outlined,
        titre: l10n.comPackagingTitle,
        aide: l10n.comPackagingHint2,
        children: [
          for (final (i, e) in _emballages.indexed) ...[
            _CarteEmballage(
              numero: i + 1,
              emballage: e,
              uniteBase: _uniteBase,
              onChanged: () => setState(() {}),
              onRetirer: () => setState(() {
                _emballages.remove(e);
                e.dispose();
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final s in [l10n.comUnitCarton, l10n.comUnitPaquet, l10n.comUnitSac, l10n.comUnitDouzaine])
                if (s != _uniteBase && !_emballages.any((e) => e.nom.text.trim() == s))
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18, color: AppColors.green),
                    label: Text(s),
                    onPressed: () => setState(() => _emballages.add(_Emballage(id: const Uuid().v4(), nom: s))),
                  ),
              ActionChip(
                key: const Key('unite-ajouter'),
                avatar: const Icon(Icons.add, size: 18, color: AppColors.green),
                label: Text(l10n.comAddPackaging),
                onPressed: () => setState(() => _emballages.add(_Emballage(id: const Uuid().v4()))),
              ),
              ActionChip(
                avatar: const Icon(Icons.copy_all_outlined, size: 18),
                label: Text(l10n.comCopyUnits),
                onPressed: _copierUnites,
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Future<void> _copierUnites() async {
    final etat = ref.read(etatCommerceProvider).value;
    if (etat == null) return;
    HapticFeedback.lightImpact();
    final modele = await showModalBottomSheet<Produit>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scroll) => Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text(context.l10n.comCopyUnits, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final p in etat.produitsActifs.where((p) => p.aPlusieursUnites))
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: ProduitImage(produit: p, taille: 48),
                        title: Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(p.unites.map((u) => '1 ${u.nom} = ${qteUnite(context, u.facteur, p.uniteBase)}').join(' · ')),
                        onTap: () => Navigator.pop(context, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (modele == null || !mounted) return;
    setState(() {
      _uniteBase = modele.uniteBase;
      for (final e in _emballages) {
        e.dispose();
      }
      _emballages
        ..clear()
        ..addAll([for (final u in modele.unites) _Emballage(id: const Uuid().v4(), nom: u.nom, facteur: u.facteur)]);
    });
  }

  // ===========================================================================
  // Étape 2 : Prix & Rentabilité, Stock et Options Avancées (Style Ecomiq SaaS)
  // ===========================================================================

  List<Widget> _etapePrixStock() {
    final l10n = context.l10n;
    final droits = ref.watch(droitsCommerceProvider);
    final unites = _unitesChoisissables;
    final apercu = _produit();
    final etat = ref.watch(etatCommerceProvider).value ?? widget.etat;
    final suggeres = _attributsSuggeres(etat.racine(_categorieId)?.icone);
    for (final code in suggeres) {
      _attributs.putIfAbsent(code, TextEditingController.new);
    }

    // Calcul dynamique de la rentabilité (Marge brute)
    final prixAchatBase = _prixBase(_achat);
    final prixDetailBase = _prixBase(_detail);
    final double? margePourcent = (prixAchatBase != null && prixDetailBase != null && prixAchatBase > 0)
        ? ((prixDetailBase - prixAchatBase) * 100 / prixAchatBase)
        : null;
    final int? margeMontant = (prixAchatBase != null && prixDetailBase != null)
        ? (prixDetailBase - prixAchatBase)
        : null;

    return [
      // 1. Section « Prix & Rentabilité »
      _Section(
        icone: Icons.monetization_on_outlined,
        couleur: AppColors.gold,
        titre: 'Prix & Rentabilité',
        aide: 'Fixez les tarifs d\'achat et de vente, et surveillez votre rentabilité.',
        children: [
          _Libelle('${l10n.comRetailPrice} *', aide: l10n.comRetailPriceHint),
          _SaisiePrix(cle: 'detail', prix: _detail, unites: unites, onChanged: () => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          _Libelle(l10n.comPurchasePrice, aide: l10n.comPurchasePriceHint),
          _SaisiePrix(cle: 'achat', prix: _achat, unites: unites, onChanged: () => setState(() {})),

          // Badge dynamique de rentabilité
          if (margeMontant != null) ...[
            const SizedBox(height: AppSpacing.md),
            _BadgeRentabilite(margeMontant: margeMontant, margePourcent: margePourcent),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // 2. Section « Vente en gros » avec Toggle Switch Ecomiq
      _Section(
        icone: Icons.local_shipping_outlined,
        couleur: const Color(0xFF2563EB),
        titre: l10n.comWholesalePrice,
        aide: 'Activez un tarif préférentiel pour les clients grossistes.',
        action: Switch(
          key: const Key('produit-gros'),
          value: _venteGros,
          onChanged: (v) => setState(() {
            _venteGros = v;
            if (v && _gros.valeur == null && unites.length > 1) {
              _gros.uniteId = unites.last.$1;
            }
          }),
        ),
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _venteGros ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'La vente en gros est désactivée pour ce produit. Activez l\'interrupteur pour renseigner le prix de gros (par carton ou par lot).',
                style: TextStyle(fontSize: 13, color: AppColors.muted.withValues(alpha: 0.9), height: 1.3),
              ),
            ),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Libelle(l10n.comWholesalePrice, aide: l10n.comWholesalePriceHint),
                _SaisiePrix(cle: 'gros', prix: _gros, unites: unites, onChanged: () => setState(() {})),
              ],
            ),
          ),
        ],
      ),

      // 3. Tableau Récapitulatif si prix renseignés
      if (_detail.valeur != null) ...[
        const SizedBox(height: AppSpacing.md),
        _Section(
          icone: Icons.calculate_outlined,
          couleur: AppColors.green,
          titre: l10n.comPriceSummary,
          children: [_TableauPrix(produit: apercu)],
        ),
      ],
      const SizedBox(height: AppSpacing.md),

      // 4. Stock & Alertes
      _Section(
        icone: Icons.warehouse_outlined,
        couleur: const Color(0xFF0891B2),
        titre: l10n.comStockAndAlert,
        aide: 'Gérez le stock de départ et les seuils automatiques de réapprovisionnement.',
        children: [
          if (_creation && droits.entreeSortie) ...[
            _Libelle(l10n.comInitialStock, aide: l10n.comInitialStockHint),
            if (droits.boutiquesEntreeSortie.length > 1) ...[
              ChampBoutique(
                valeur: _boutique,
                autorisees: droits.boutiquesEntreeSortie,
                onChanged: (v) => setState(() => _boutique = v),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ChampQuantite(
              key: ValueKey('stock-${_signatureUnites()}'),
              champKey: const Key('produit-stock-initial'),
              produit: apercu,
              uniteInitiale: apercu.plusGrandeUnite,
              quantiteInitiale: _stockInitial,
              label: l10n.comQuantity,
              onChanged: (q, u) => setState(() {
                _stockInitial = q;
                _uniteStock = u;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          _Libelle(l10n.comAlertThreshold, aide: l10n.comAlertThresholdHint),
          ChampQuantite(
            key: ValueKey('seuil-${_signatureUnites()}'),
            champKey: const Key('produit-seuil'),
            produit: apercu,
            quantiteInitiale: _seuil.estNul ? null : _seuil,
            zeroAutorise: true,
            label: l10n.comQuantity,
            onChanged: (q, u) => setState(() => _seuil = (q ?? Qte.zero).fois(u.facteur)),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),

      // 5. Options Avancées
      Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _reference.text.isNotEmpty || _fournisseurId != null || _fractionnee,
            leading: const Icon(Icons.tune_rounded, color: AppColors.muted),
            title: Text(l10n.comStepOptions, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Libelle(l10n.comReferenceShort),
              TextField(
                controller: _reference,
                textCapitalization: TextCapitalization.characters,
                decoration: _decoration(
                  hint: l10n.comReferenceHint,
                  suffixe: IconButton(
                    tooltip: l10n.comGenerateReference,
                    icon: const Icon(Icons.auto_fix_high_outlined, color: AppColors.green),
                    onPressed: () => setState(() => _reference.text = _referenceProposee(etat)),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _Libelle(l10n.comMainSupplier),
              _ChampCliquable(
                icone: Icons.local_shipping_outlined,
                texte: nomContact(ref, _fournisseurId) ?? l10n.comSupplierNone,
                vide: _fournisseurId == null,
                onTap: () async {
                  final c = await choisirContact(context, RelationContact.fournisseur);
                  if (c != null) setState(() => _fournisseurId = c.id);
                },
                onEffacer: _fournisseurId == null ? null : () => setState(() => _fournisseurId = null),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                key: const Key('produit-fraction'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.comSellFractions, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(l10n.comSellFractionsHint),
                value: _fractionnee,
                onChanged: (v) => setState(() => _fractionnee = v),
              ),
              if (_fractionnee) ...[
                _Libelle(l10n.comMinimumStep),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final (texte, pas) in [('¼', 2500), ('½', 5000), ('0,1', 1000), ('0,01', 100)])
                      ChoiceChip(
                        label: Text('$texte $_uniteBase'),
                        selected: _pas.brut == pas,
                        onSelected: (_) => setState(() => _pas = Qte(pas)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              _Libelle(l10n.comCharacteristics),
              for (final MapEntry(key: code, value: c) in _attributs.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextField(controller: c, decoration: _decoration(hint: libelleAttribut(l10n, code))),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.comAddCharacteristic),
                  onPressed: () async {
                    final nom = await _demanderTexte(l10n.comAddCharacteristic, l10n.comCharacteristicName);
                    if (nom != null) setState(() => _attributs.putIfAbsent(nom, TextEditingController.new));
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _Libelle(l10n.comDescription),
              TextField(controller: _description, maxLines: 3, maxLength: 1000, decoration: _decoration()),
            ],
          ),
        ),
      ),
    ];
  }

  String _signatureUnites() => [_uniteBase, for (final e in _emballages) '${e.nom.text}:${e.facteur.text}'].join('|');

  String _referenceProposee(EtatCommerce etat) {
    final lettres = normaliserRecherche(_nom.text).replaceAll(RegExp(r'[^a-z]'), '').toUpperCase();
    final prefixe = (lettres.isEmpty ? 'PRD' : lettres).padRight(3, 'X').substring(0, 3);
    return '$prefixe-${(etat.produits.length + 1).toString().padLeft(4, '0')}';
  }

  Future<String?> _demanderTexte(String titre, String? aide) async {
    final controleur = TextEditingController();
    final l10n = context.l10n;
    final texte = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.greenSoft,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(titre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: controleur,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: aide,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (t) => Navigator.pop(ctx, t),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.commonCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx, controleur.text),
                      child: Text(l10n.commonConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controleur.dispose();
    final t = texte?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static List<String> _attributsSuggeres(String? icone) => switch (icone) {
        'carrelage' => ['marque', 'dimensions', 'couleur', 'finition'],
        'peinture' => ['marque', 'couleur', 'volume', 'type'],
        'electricite' => ['marque', 'section', 'longueur'],
        'vetements' || 'chaussures' => ['marque', 'taille', 'couleur'],
        'outils' || 'electronique' || 'telephonie' => ['marque', 'modele'],
        'materiaux' => ['marque', 'poids'],
        _ => ['marque'],
      };
}

// =============================================================================
// Éléments Visuels du Formulaire (Modern Ecomiq SaaS Style)
// =============================================================================

/// Champ moderne : fond blanc, coins arrondis, libellé au-dessus.
InputDecoration _decoration({String? hint, Widget? prefixe, Widget? suffixe, String? suffixeTexte}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
      prefixIcon: prefixe,
      suffixIcon: suffixe,
      suffixText: suffixeTexte,
      suffixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.green, width: 2)),
    );

/// Libellé complet au-dessus d'un champ, avec une aide facultative.
class _Libelle extends StatelessWidget {
  const _Libelle(this.texte, {this.aide});
  final String texte;
  final String? aide;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texte, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.ink)),
            if (aide != null) ...[
              const SizedBox(height: 2),
              Text(aide!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
            ],
          ],
        ),
      );
}

/// Carte de section conteneur : icône avec fond teinté, titre, aide, contenu.
class _Section extends StatelessWidget {
  const _Section({
    required this.icone,
    required this.titre,
    required this.children,
    this.aide,
    this.action,
    this.couleur = AppColors.green,
  });

  final IconData icone;
  final String titre;
  final String? aide;
  final Widget? action;
  final Color couleur;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: couleur.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(icone, color: couleur, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
                        if (aide != null) ...[
                          const SizedBox(height: 2),
                          Text(aide!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.35)),
                        ],
                      ],
                    ),
                  ),
                  ?action,
                ],
              ),
              if (children.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), ...children],
            ],
          ),
        ),
      );
}

/// Progression des étapes épurée (cliquable).
class _Progression extends StatelessWidget {
  const _Progression({required this.etapes, required this.courante, required this.onTap});
  final List<String> etapes;
  final int courante;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
        child: Row(
          children: [
            for (final (i, e) in etapes.indexed) ...[
              if (i > 0)
                Container(
                  width: 24,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i <= courante ? AppColors.green : AppColors.border,
                ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: i <= courante ? AppColors.green : AppColors.border,
                          child: i < courante
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : Text('${i + 1}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: i <= courante ? Colors.white : AppColors.muted)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e,
                            maxLines: 2,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.2,
                              fontWeight: i == courante ? FontWeight.w800 : FontWeight.w600,
                              color: i == courante ? AppColors.ink : AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}

class _BarreActions extends StatelessWidget {
  const _BarreActions({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, -3))],
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
            child: Row(children: children),
          ),
        ),
      );
}

/// Box Médias moderne & dynamique (Style Dribbble / Ecomiq SaaS)
class _BoxUploadMedias extends StatelessWidget {
  const _BoxUploadMedias({
    required this.photos,
    required this.produit,
    required this.onAjouter,
    required this.onRetirer,
    required this.onDefinirPrincipale,
  });

  final List<String> photos;
  final Produit produit;
  final VoidCallback? onAjouter;
  final ValueChanged<int> onRetirer;
  final ValueChanged<int> onDefinirPrincipale;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      // Zone dropzone vide avec grand bouton
      return InkWell(
        key: const Key('produit-photo-box'),
        borderRadius: BorderRadius.circular(16),
        onTap: onAjouter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.green.withValues(alpha: 0.35), width: 1.6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_a_photo_outlined, color: AppColors.green, size: 30),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ajouter des photos du produit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Prenez une photo ou choisissez depuis la galerie',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted.withValues(alpha: 0.9)),
              ),
            ],
          ),
        ),
      );
    }

    // Vue avec photos : Grande photo principale + vignettes secondaires
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Photo Principale
        Stack(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ProduitImage(produit: produit, chemin: photos.first, taille: double.infinity, rayon: 0),
              ),
            ),
            PositionedDirectional(
              start: 12,
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                    SizedBox(width: 4),
                    Text('Photo principale', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => onRetirer(0),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded, size: 18, color: AppColors.negative),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Vignettes secondaires
        SizedBox(
          height: 74,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 1; i < photos.length; i++) ...[
                Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onDefinirPrincipale(i),
                      child: Container(
                        width: 74,
                        height: 74,
                        margin: const EdgeInsetsDirectional.only(end: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ProduitImage(produit: produit, chemin: photos[i], taille: 74, rayon: 0),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      top: 4,
                      end: 12,
                      child: InkWell(
                        onTap: () => onRetirer(i),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.close, size: 12, color: AppColors.negative),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (onAjouter != null)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onAjouter,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.green, size: 22),
                        SizedBox(height: 2),
                        Text('Ajouter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.greenPressed)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Choix de l'unité de base : tuiles avec icône, faciles à toucher.
class _ChoixUniteBase extends StatelessWidget {
  const _ChoixUniteBase({required this.valeur, required this.onChanged, required this.onAutre});
  final String valeur;
  final ValueChanged<String> onChanged;
  final VoidCallback onAutre;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final unites = <(String, IconData)>[
      (l10n.comUnitPiece, Icons.view_in_ar_outlined),
      (l10n.comUnitCarton, Icons.inventory_2_outlined),
      (l10n.comUnitPaquet, Icons.redeem_outlined),
      (l10n.comUnitSac, Icons.shopping_bag_outlined),
      (l10n.comUnitBidon, Icons.oil_barrel_outlined),
      (l10n.comUnitBouteille, Icons.liquor_outlined),
      (l10n.comUnitBoite, Icons.all_inbox_outlined),
      (l10n.comUnitSachet, Icons.local_mall_outlined),
      (l10n.comUnitKg, Icons.scale_outlined),
      (l10n.comUnitLitre, Icons.water_drop_outlined),
      (l10n.comUnitMetre, Icons.straighten_rounded),
      (l10n.comUnitRouleau, Icons.donut_large_outlined),
    ];
    final personnalisee = valeur.isNotEmpty && !unites.any((u) => u.$1 == valeur);
    Widget tuile(String texte, IconData icone, bool choisie, VoidCallback onTap, {Key? key}) => SizedBox(
          width: 98,
          child: Material(
            color: choisie ? AppColors.greenSoft : AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: choisie ? AppColors.green : AppColors.border, width: choisie ? 2 : 1),
            ),
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                child: Column(
                  children: [
                    Icon(icone, color: choisie ? AppColors.green : AppColors.muted),
                    const SizedBox(height: 6),
                    Text(texte,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: choisie ? FontWeight.w800 : FontWeight.w600,
                          color: choisie ? AppColors.greenPressed : AppColors.ink,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ),
          ),
        );
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final (texte, icone) in unites)
          tuile(texte, icone, valeur == texte, () => onChanged(texte), key: Key('unite-base-$texte')),
        tuile(personnalisee ? valeur : l10n.comOtherUnit, Icons.edit_outlined, personnalisee, onAutre),
      ],
    );
  }
}

/// « Emballage n » : nom et contenu, avec la phrase de vérification.
class _CarteEmballage extends StatelessWidget {
  const _CarteEmballage({
    required this.numero,
    required this.emballage,
    required this.uniteBase,
    required this.onChanged,
    required this.onRetirer,
  });

  final int numero;
  final _Emballage emballage;
  final String uniteBase;
  final VoidCallback onChanged;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final e = emballage;
    final facteur = e.facteurQte;
    final nomBaseAccorde = nomUnite(context, uniteBase, Qte.depuis(2)).toLowerCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.greenSoft,
                child: Text('$numero', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.nom.text.trim().isEmpty ? l10n.comPackagingName : e.nom.text.trim(),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
              IconButton(
                tooltip: l10n.commonDelete,
                onPressed: onRetirer,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.negative),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Libelle(l10n.comPackagingName),
          TextField(
            controller: e.nom,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoration(hint: l10n.comUnitCarton),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: AppSpacing.md),
          _Libelle(l10n.comPackagingContains(nomBaseAccorde)),
          TextField(
            key: Key('unite-facteur-${e.id}'),
            controller: e.facteur,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            decoration: _decoration(hint: '10', suffixeTexte: nomBaseAccorde),
            onChanged: (_) => onChanged(),
          ),
          if (e.valide) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.greenSoft, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('1 ${e.nom.text.trim()} = ${qteUnite(context, facteur!, uniteBase)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.greenPressed)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Montant + unité du prix (« 8 000 FCFA par Carton ») et l'équivalent calculé.
class _SaisiePrix extends ConsumerWidget {
  const _SaisiePrix({required this.cle, required this.prix, required this.unites, required this.onChanged});
  final String cle;
  final _PrixSaisi prix;
  final List<(String, String, Qte)> unites;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final choisie = unites.where((u) => u.$1 == prix.uniteId).firstOrNull ?? unites.first;
    final valeur = prix.valeur;

    final equivalents = <String>[];
    if (valeur != null) {
      final base = choisie.$1 == UniteVente.idBase ? valeur : CalculPrix.base(valeur, choisie.$3);
      for (final u in unites) {
        if (u.$1 == choisie.$1) continue;
        final p = u.$1 == UniteVente.idBase ? base : CalculPrix.lot(base, u.$3);
        equivalents.add(l10n.comEquivalentPrice(montant(context, ref, p), u.$2));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (unites.length > 1) ...[
          _Libelle(l10n.comPricePer),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final u in unites)
                ChoiceChip(
                  key: Key('prix-$cle-unite-${u.$2}'),
                  label: Text(u.$2),
                  avatar: u.$1 == choisie.$1 ? null : const Icon(Icons.radio_button_unchecked, size: 16),
                  selected: u.$1 == choisie.$1,
                  showCheckmark: true,
                  onSelected: (_) {
                    prix.uniteId = u.$1;
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        TextField(
          key: Key('prix-$cle'),
          controller: prix.montant,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          decoration: _decoration(
            hint: l10n.comAmountHint,
            suffixeTexte: '${devise == 'XOF' ? 'FCFA' : devise} / ${choisie.$2}',
          ),
          onChanged: (_) => onChanged(),
        ),
        if (equivalents.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          for (final e in equivalents)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(e, style: const TextStyle(color: AppColors.greenPressed, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Badge de Rentabilité (Marge brute estimée)
class _BadgeRentabilite extends ConsumerWidget {
  const _BadgeRentabilite({required this.margeMontant, required this.margePourcent});
  final int margeMontant;
  final double? margePourcent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positif = margeMontant >= 0;
    final texteMarge = '${positif ? '+' : ''}${montant(context, ref, margeMontant)}';
    final textePourcent = margePourcent != null ? ' (${positif ? '+' : ''}${margePourcent!.toStringAsFixed(1)}%)' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: positif ? AppColors.greenSoft : AppColors.negativeSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: positif ? AppColors.green.withValues(alpha: 0.3) : AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            positif ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: positif ? AppColors.green : AppColors.negative,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: AppColors.ink),
                children: [
                  const TextSpan(text: 'Rentabilité estimée : ', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(
                    text: '$texteMarge$textePourcent',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: positif ? AppColors.greenPressed : AppColors.negative,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tableau récapitulatif : chaque unité avec ses prix (détail, gros, achat, bénéfice).
class _TableauPrix extends ConsumerWidget {
  const _TableauPrix({required this.produit});
  final Produit produit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = produit;
    final gros = p.prixGros != null;
    final achat = p.prixAchat != null;
    const entete = TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.3)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AppColors.background),
            children: [
              _Cellule(Text(l10n.comUnit, style: entete)),
              _Cellule(Text(l10n.comRetail, style: entete, textAlign: TextAlign.end)),
              if (gros) _Cellule(Text(l10n.comWholesale, style: entete, textAlign: TextAlign.end)),
              if (achat) _Cellule(Text(l10n.comProfit, style: entete, textAlign: TextAlign.end)),
            ],
          ),
          for (final u in p.toutesUnites)
            TableRow(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              children: [
                _Cellule(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (!u.estBase)
                      Text('= ${qteUnite(context, u.facteur, p.uniteBase)}',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                )),
                _Cellule(Text(montant(context, ref, u.prixDetail),
                    textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.green))),
                if (gros)
                  _Cellule(Text(u.prixGros == null ? '—' : montant(context, ref, u.prixGros!),
                      textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2563EB)))),
                if (achat)
                  _Cellule(Text(
                    switch (CalculPrix.benefice(u.prixDetail, u.prixAchat)) {
                      final b? => montant(context, ref, b),
                      null => '—',
                    },
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.muted),
                  )),
              ],
            ),
        ],
      ),
    );
  }
}

class _Cellule extends StatelessWidget {
  const _Cellule(this.child);
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(10), child: child);
}

/// Champ qui ouvre un choix (fournisseur…), avec effacement.
class _ChampCliquable extends StatelessWidget {
  const _ChampCliquable({required this.icone, required this.texte, required this.vide, required this.onTap, this.onEffacer});
  final IconData icone;
  final String texte;
  final bool vide;
  final VoidCallback onTap;
  final VoidCallback? onEffacer;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icone, color: vide ? AppColors.muted : AppColors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texte,
                      style: TextStyle(
                        fontWeight: vide ? FontWeight.w500 : FontWeight.w700,
                        color: vide ? AppColors.muted : AppColors.ink,
                      )),
                ),
                if (onEffacer != null)
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: onEffacer)
                else
                  const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
      );
}

/// Champ catégorie qui ouvre la liste (catégories et sous-catégories) dans un BottomSheet moderne.
class _ChoixCategorie extends ConsumerWidget {
  const _ChoixCategorie({required this.etat, required this.categorieId, required this.onChanged});
  final EtatCommerce etat;
  final String? categorieId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cat = etat.categorie(categorieId);
    final parent = etat.categorie(cat?.parentId);
    final racine = parent ?? cat;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      child: InkWell(
        key: const Key('produit-categorie'),
        borderRadius: BorderRadius.circular(14),
        onTap: () => _ouvrir(context, ref),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CategorieIcone(categorie: racine, taille: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cat == null ? l10n.comChooseCategory : (parent != null ? '${parent.nom} › ${cat.nom}' : cat.nom),
                  style: TextStyle(
                    fontWeight: cat == null ? FontWeight.w500 : FontWeight.w700,
                    color: cat == null ? AppColors.muted : AppColors.ink,
                    fontSize: 15,
                  ),
                ),
              ),
              const Icon(Icons.expand_more_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _ouvrir(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.read(droitsCommerceProvider);
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetContext, defilement) => Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l10n.comChooseCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ),
                    if (droits.creerProduits)
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(l10n.comNewCategory),
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          final cree = await editerCategorie(context, ref);
                          if (cree != null) onChanged(cree.id);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: defilement,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.do_not_disturb_on_outlined, color: AppColors.muted),
                      title: Text(l10n.comNoCategory),
                      trailing: categorieId == null ? const Icon(Icons.check, color: AppColors.green) : null,
                      onTap: () {
                        onChanged(null);
                        Navigator.pop(sheetContext);
                      },
                    ),
                    for (final r in etat.categoriesRacines) ...[
                      ListTile(
                        leading: CategorieIcone(categorie: r, taille: 36),
                        title: Text(r.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
                        trailing: categorieId == r.id ? const Icon(Icons.check, color: AppColors.green) : null,
                        onTap: () {
                          onChanged(r.id);
                          Navigator.pop(sheetContext);
                        },
                      ),
                      for (final s in etat.sousCategories(r.id))
                        ListTile(
                          contentPadding: const EdgeInsetsDirectional.only(start: 64, end: 16),
                          leading: const Icon(Icons.subdirectory_arrow_right_rounded, size: 18, color: AppColors.muted),
                          title: Text(s.nom),
                          trailing: categorieId == s.id ? const Icon(Icons.check, color: AppColors.green) : null,
                          onTap: () {
                            onChanged(s.id);
                            Navigator.pop(sheetContext);
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Formulaire de Catégorie : Photo OU Icône & Couleur
// =============================================================================

/// Mode de visuel d'une catégorie.
enum _ModeVisuel { icone, photo }

/// Création / modification d'une catégorie : nom, icône OU photo réelle, couleur.
Future<CategorieProduit?> editerCategorie(
  BuildContext context,
  WidgetRef ref, {
  String? parentId,
  CategorieProduit? initiale,
}) async {
  final couleurDefaut = VisuelsCategories.couleurs[
      (ref.read(etatCommerceProvider).value?.categories.length ?? 0) % VisuelsCategories.couleurs.length];

  final saisie = await showDialog<({String nom, String? icone, Uint8List? photoBytes, String couleur})>(
    context: context,
    builder: (_) => _DialogueCategorie(initiale: initiale, parentId: parentId, couleurDefaut: couleurDefaut),
  );
  if (saisie == null || !context.mounted) return null;

  final ctx = ref.read(contexteActifProvider);
  if (ctx == null) return null;
  final gerer = ref.read(gererCommerceProvider);

  debugPrint('COMMERCE: Début enregistrement catégorie "${saisie.nom}" (parent=$parentId)');
  try {
    String? iconeFinal = saisie.icone;
    final catId = initiale?.id ?? const Uuid().v4();

    // Si une photo a été choisie, on l'enregistre dans le stockage
    if (saisie.photoBytes != null) {
      debugPrint('COMMERCE: Upload photo pour catégorie $catId...');
      final cheminPhoto = await ref.read(photosProduitsProvider).ajouter(
            entrepriseId: ctx.entreprise!.id,
            produitId: 'cat_$catId',
            octets: saisie.photoBytes!,
          );
      iconeFinal = 'photo:$cheminPhoto';
    }

    if (initiale != null) {
      final apres = initiale.copyWith(
        nom: saisie.nom,
        icone: () => iconeFinal,
        couleur: () => saisie.couleur,
      );
      await gerer.modifierCategorie(ctx, initiale, apres);
      debugPrint('COMMERCE: Catégorie modifiée ID=${initiale.id}');
      return apres;
    }

    final nouvelle = await gerer.creerCategorie(
      ctx,
      nom: saisie.nom,
      parentId: parentId,
      icone: parentId == null ? iconeFinal : null,
      couleur: parentId == null ? saisie.couleur : null,
    );
    debugPrint('COMMERCE: Catégorie créée ID=${nouvelle.id}');
    return nouvelle;
  } catch (e) {
    debugPrint('COMMERCE ERROR: Échec enregistrement catégorie: $e');
    if (context.mounted) signalerErreur(context, e);
    return null;
  }
}

/// Dialogue de création / modification d'une catégorie avec support Photo OU Icône.
class _DialogueCategorie extends StatefulWidget {
  const _DialogueCategorie({required this.initiale, required this.parentId, required this.couleurDefaut});
  final CategorieProduit? initiale;
  final String? parentId;
  final String couleurDefaut;

  @override
  State<_DialogueCategorie> createState() => _DialogueCategorieState();
}

class _DialogueCategorieState extends State<_DialogueCategorie> {
  late final _nom = TextEditingController(text: widget.initiale?.nom);
  late _ModeVisuel _mode = (widget.initiale?.icone?.startsWith('photo:') ?? false) ? _ModeVisuel.photo : _ModeVisuel.icone;
  late String _icone = widget.initiale?.icone?.startsWith('photo:') ?? false
      ? 'autre'
      : (widget.initiale?.icone ?? 'autre');
  late String _couleur = widget.initiale?.couleur ?? widget.couleurDefaut;
  late bool _iconeChoisie = widget.initiale?.icone != null && !widget.initiale!.icone!.startsWith('photo:');

  Uint8List? _photoBytes;
  late String? _photoExistanteChemin = widget.initiale?.icone?.startsWith('photo:') ?? false
      ? widget.initiale!.icone!.substring(6)
      : null;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  void _nomChange(String texte) {
    if (_iconeChoisie || _mode == _ModeVisuel.photo) return;
    final suggestion = VisuelsCategories.suggerer(texte);
    if (suggestion != _icone) setState(() => _icone = suggestion);
  }

  Future<void> _choisirPhoto(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 80);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoExistanteChemin = null;
      });
    } catch (e) {
      if (mounted) signalerErreur(context, e);
    }
  }

  Future<void> _choisirSourcePhoto() async {
    HapticFeedback.mediumImpact();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Source de la photo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.photo_camera_outlined, color: AppColors.green),
                ),
                title: const Text('Prendre une photo', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: const Icon(Icons.photo_library_outlined, color: Color(0xFF4F46E5)),
                ),
                title: const Text('Choisir depuis la galerie', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _choisirPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final teinte = VisuelsCategories.couleur(_couleur);
    final racine = widget.parentId == null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppColors.greenSoft,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête stylisé
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initiale?.nom ?? (racine ? l10n.comNewCategory : l10n.comNewSubCategory),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Aperçu de la catégorie (Card Fintech)
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: teinte.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                          border: Border.all(color: AppColors.surface, width: 3),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: teinte.withValues(alpha: 0.08)),
                            _mode == _ModeVisuel.photo && (_photoBytes != null || _photoExistanteChemin != null)
                                ? (_photoBytes != null
                                    ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                                    : Consumer(builder: (_, ref, _) {
                                        final octets = ref.watch(photoProduitProvider(_photoExistanteChemin!));
                                        return switch (octets) {
                                          AsyncData(value: final o?) => Image.memory(o, fit: BoxFit.cover),
                                          _ => Icon(VisuelsCategories.icone(_icone), color: teinte, size: 44),
                                        };
                                      }))
                                : Icon(VisuelsCategories.icone(_icone), color: teinte, size: 44),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Champ Nom
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        key: const Key('categorie-nom'),
                        controller: _nom,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (v) {
                          _nomChange(v);
                          setState(() {}); // Pour activer/désactiver le bouton
                        },
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Nom de la catégorie',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          prefixIcon: const Icon(Icons.label_outline_rounded, color: AppColors.muted),
                        ),
                      ),
                    ),

                    if (racine) ...[
                      const SizedBox(height: 24),
                      // Sélecteur Mode
                      Row(
                        children: [
                          Expanded(
                            child: _BoutonMode(
                              actif: _mode == _ModeVisuel.icone,
                              icone: Icons.palette_outlined,
                              label: 'Icône',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _mode = _ModeVisuel.icone);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BoutonMode(
                              actif: _mode == _ModeVisuel.photo,
                              icone: Icons.add_a_photo_outlined,
                              label: 'Photo',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _mode = _ModeVisuel.photo);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      if (_mode == _ModeVisuel.photo) ...[
                        InkWell(
                          onTap: _choisirSourcePhoto,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.green.withValues(alpha: 0.3), style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  _photoBytes != null || _photoExistanteChemin != null
                                      ? Icons.check_circle_rounded
                                      : Icons.camera_alt_outlined,
                                  color: AppColors.green,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _photoBytes != null || _photoExistanteChemin != null
                                      ? 'Changer la photo'
                                      : 'Prendre ou choisir une photo',
                                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Grille d'icônes aérée
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final MapEntry(key: code, value: ic) in VisuelsCategories.icones.entries)
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _icone = code;
                                      _iconeChoisie = true;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _icone == code ? teinte.withValues(alpha: 0.1) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _icone == code ? teinte : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(ic, size: 24, color: _icone == code ? teinte : AppColors.muted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Palette de couleurs
                        const Text('Couleur thématique',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final c in VisuelsCategories.couleurs)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _couleur = c);
                                },
                                child: AnimatedScale(
                                  scale: _couleur == c ? 1.2 : 1.0,
                                  duration: const Duration(milliseconds: 150),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: VisuelsCategories.couleur(c),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        if (_couleur == c)
                                          BoxShadow(
                                              color: VisuelsCategories.couleur(c).withValues(alpha: 0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2)),
                                      ],
                                    ),
                                    child: _couleur == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.commonCancel, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: AppColors.green.withValues(alpha: 0.3),
                      ),
                      onPressed: _nom.text.trim().isEmpty
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              Navigator.pop(
                                context,
                                (
                                  nom: _nom.text.trim(),
                                  icone: _mode == _ModeVisuel.photo
                                      ? (_photoExistanteChemin != null ? 'photo:$_photoExistanteChemin' : null)
                                      : _icone,
                                  photoBytes: _mode == _ModeVisuel.photo ? _photoBytes : null,
                                  couleur: _couleur,
                                ),
                              );
                            },
                      child: Text(l10n.commonSave, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonMode extends StatelessWidget {
  const _BoutonMode({required this.actif, required this.icone, required this.label, required this.onTap});
  final bool actif;
  final IconData icone;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: actif ? AppColors.ink : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        elevation: actif ? 4 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: actif ? Colors.white : AppColors.muted, size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: actif ? Colors.white : AppColors.ink, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ),
      );
}


/// Libellé traduit d'une caractéristique (codes connus) ou nom libre.
String libelleAttribut(AppLocalizations l10n, String code) => switch (code) {
      'marque' => l10n.comAttrMarque,
      'modele' => l10n.comAttrModele,
      'couleur' => l10n.comAttrCouleur,
      'dimensions' => l10n.comAttrDimensions,
      'finition' => l10n.comAttrFinition,
      'volume' => l10n.comAttrVolume,
      'type' => l10n.comAttrType,
      'section' => l10n.comAttrSection,
      'longueur' => l10n.comAttrLongueur,
      'taille' => l10n.comAttrTaille,
      'poids' => l10n.comAttrPoids,
      'emplacement' => l10n.comAttrEmplacement,
      _ => code,
    };
