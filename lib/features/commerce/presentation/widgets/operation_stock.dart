import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'champ_quantite.dart';
import 'commerce_widgets.dart';

enum OperationStock { entree, sortie, transfert, inventaire }

/// Ouvre l'écran modal moderne d'une opération de stock (ajustement, inventaire, entrée, sortie, transfert).
Future<void> ouvrirOperationStock(
  BuildContext context, {
  required Produit produit,
  required OperationStock operation,
  String? perimetreId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OperationSheet(produit: produit, operation: operation, perimetreId: perimetreId),
    );

class _OperationSheet extends ConsumerStatefulWidget {
  const _OperationSheet({required this.produit, required this.operation, this.perimetreId});
  final Produit produit;
  final OperationStock operation;
  final String? perimetreId;

  @override
  ConsumerState<_OperationSheet> createState() => _OperationSheetState();
}

class _OperationSheetState extends ConsumerState<_OperationSheet> {
  String? _boutique;
  String? _vers;
  Qte? _quantite;
  late UniteVente _unite;
  MotifMouvement? _motif;
  final _note = TextEditingController();
  bool _noteVisible = false;
  bool _enCours = false;

  Produit get p => widget.produit;
  OperationStock get op => widget.operation;

  List<String> get _autorisees {
    final d = ref.read(droitsCommerceProvider);
    final liste = op == OperationStock.entree || op == OperationStock.sortie
        ? d.boutiquesEntreeSortie
        : d.boutiquesAjustement;
    if (liste.isNotEmpty) return liste;
    final fallback = [for (final b in ref.read(boutiquesProvider)) b.id];
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    final autorisees = _autorisees;
    final souhaitee = widget.perimetreId ?? ref.read(boutiqueCouranteProvider);
    _boutique = (souhaitee != null && autorisees.contains(souhaitee))
        ? souhaitee
        : (autorisees.firstOrNull ?? ref.read(boutiquesProvider).firstOrNull?.id);

    if (op == OperationStock.transfert) {
      _vers = autorisees.where((b) => b != _boutique).firstOrNull;
    }
    final memo = ref.read(unitesMemoriseesProvider.notifier).pour('stock', p.id);
    _unite = p.unite(memo ?? p.plusGrandeUnite.id);
    _motif = switch (op) {
      OperationStock.entree => MotifMouvement.achat,
      OperationStock.sortie => MotifMouvement.perte,
      OperationStock.inventaire => MotifMouvement.erreurComptage,
      OperationStock.transfert => MotifMouvement.transfert,
    };
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Qte? get _base => _quantite?.fois(_unite.facteur);

  bool _valide(Qte? base) {
    if (base == null || _boutique == null) return false;
    if (op == OperationStock.inventaire) return !base.estNegatif;
    if (!base.estPositif) return false;
    if (!p.venteFractionnee && !base.estEntier) return false;
    if (p.venteFractionnee && !base.estMultipleDe(p.pasMinimum)) return false;
    if (op == OperationStock.transfert && (_vers == null || _vers == _boutique)) return false;
    return true;
  }

  Future<void> _valider() async {
    final l10n = context.l10n;
    final ctx = ref.read(contexteActifProvider);
    final etat = ref.read(etatCommerceProvider).value;
    final q = _quantite;
    if (ctx == null || etat == null || q == null || _boutique == null) return;

    setState(() => _enCours = true);
    final gerer = ref.read(gererCommerceProvider);
    try {
      switch (op) {
        case OperationStock.entree || OperationStock.sortie:
          await gerer.mouvement(
            ctx,
            etat,
            produit: p,
            perimetreId: _boutique!,
            entree: op == OperationStock.entree,
            motif: _motif ?? (op == OperationStock.entree ? MotifMouvement.achat : MotifMouvement.perte),
            quantite: q,
            unite: _unite,
            note: _note.text,
          );
        case OperationStock.inventaire:
          await gerer.inventaire(
            ctx,
            etat,
            produit: p,
            perimetreId: _boutique!,
            compte: q,
            unite: _unite,
            motif: _motif ?? MotifMouvement.erreurComptage,
            note: _note.text,
          );
        case OperationStock.transfert:
          await gerer.transferer(
            ctx,
            etat,
            produit: p,
            dePerimetreId: _boutique!,
            versPerimetreId: _vers ?? _boutique!,
            quantite: q,
            unite: _unite,
            note: _note.text,
          );
      }
      ref.read(unitesMemoriseesProvider.notifier).retenir('stock', p.id, _unite.id);
      if (!mounted) return;
      final message = op == OperationStock.transfert
          ? l10n.comTransferDone(qteUnite(context, q, _unite.nom), nomBoutique(ref, _vers ?? ''))
          : (op == OperationStock.inventaire ? '✓ Inventaire enregistré avec succès' : l10n.comStockUpdated);
      Navigator.of(context).pop();
      confirmer(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enCours = false);
      signalerErreur(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value;
    final autorisees = _autorisees;
    final base = _base;
    final avant = _boutique == null || etat == null ? Qte.zero : etat.quantiteBoutique(p.id, _boutique!);
    final apres = switch (op) {
      OperationStock.entree => avant + (base ?? Qte.zero),
      OperationStock.inventaire => base ?? avant,
      _ => avant - (base ?? Qte.zero),
    };
    final insuffisant = (op == OperationStock.sortie || op == OperationStock.transfert) && base != null && base > avant;
    final ecart = op == OperationStock.inventaire && base != null ? base - avant : null;
    final valide = _valide(base) && !insuffisant;

    final (titre, icone, bouton, couleurTheme) = switch (op) {
      OperationStock.entree => (l10n.comNewEntry, Icons.add_circle_outline, l10n.comSaveEntry, AppColors.green),
      OperationStock.sortie => (l10n.comNewExit, Icons.remove_circle_outline, l10n.comConfirmExit, AppColors.warning),
      OperationStock.transfert => (l10n.comTransferStock, Icons.swap_horiz_rounded, l10n.comConfirmTransfer, const Color(0xFF2563EB)),
      OperationStock.inventaire => (l10n.comInventory, Icons.fact_check_outlined, l10n.comValidateInventory, AppColors.green),
    };

    final motifs = switch (op) {
      OperationStock.entree => MotifMouvement.entrees,
      OperationStock.sortie => MotifMouvement.sorties,
      OperationStock.inventaire => MotifMouvement.inventaire,
      OperationStock.transfert => const <MotifMouvement>[],
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. En-tête Modal Moderne
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: couleurTheme.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icone, color: couleurTheme, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. Fiche résumé du produit
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  ProduitImage(produit: p, taille: 54, rayon: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Text('En stock : ', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                            Text(
                              quantiteLisible(context, p, avant),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 3. Sélecteur de Boutique si applicable
            if (autorisees.length > 1 || op == OperationStock.transfert) ...[
              ChampBoutique(
                key: const Key('operation-boutique'),
                valeur: _boutique,
                autorisees: autorisees,
                label: op == OperationStock.transfert ? l10n.comFrom : l10n.comShop,
                onChanged: (v) => setState(() {
                  _boutique = v;
                  if (_vers == v) _vers = autorisees.where((b) => b != v).firstOrNull;
                }),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (op == OperationStock.transfert) ...[
              ChampBoutique(
                key: const Key('operation-vers'),
                valeur: _vers,
                autorisees: autorisees,
                exclure: _boutique,
                label: l10n.comTo,
                onChanged: (v) => setState(() => _vers = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 4. Saisie de Quantité et Unité
            ChampQuantite(
              champKey: const Key('operation-quantite'),
              produit: p,
              uniteInitiale: _unite,
              autofocus: true,
              zeroAutorise: op == OperationStock.inventaire,
              label: op == OperationStock.inventaire ? 'Quantité réelle comptée' : l10n.comHowMany,
              onChanged: (q, u) => setState(() {
                _quantite = q;
                _unite = u;
              }),
            ),

            // Raccourcis rapides pour inventaire
            if (op == OperationStock.inventaire) ...[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  ActionChip(
                    label: const Text('0 (Rupture)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.surface,
                    onPressed: () {
                      setState(() => _quantite = Qte.zero);
                    },
                  ),
                  if (!avant.estNul)
                    ActionChip(
                      label: Text('Même stock (${formatQte(context, avant.divisePar(_unite.facteur))})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      backgroundColor: AppColors.surface,
                      onPressed: () {
                        setState(() => _quantite = avant.divisePar(_unite.facteur));
                      },
                    ),
                ],
              ),
            ],

            // 5. Écart d'inventaire / Visual Diff Card
            if (base != null && _boutique != null) ...[
              const SizedBox(height: AppSpacing.md),
              if (insuffisant)
                _Alerte(l10n.comStockInsufficientInline(quantiteLisible(context, p, avant.max(Qte.zero))))
              else if (op == OperationStock.inventaire && ecart != null)
                _CarteEcartInventaire(
                  avant: quantiteLisible(context, p, avant),
                  apres: quantiteLisible(context, p, apres),
                  ecart: ecart,
                  uniteBase: p.uniteBase,
                )
              else
                AvantApres(
                  titre: op == OperationStock.transfert ? nomBoutique(ref, _boutique!) : l10n.comStockPreview,
                  avant: quantiteLisible(context, p, avant),
                  apres: quantiteLisible(context, p, apres),
                ),
              if (op == OperationStock.transfert && _vers != null && !insuffisant && etat != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AvantApres(
                  titre: nomBoutique(ref, _vers!),
                  avant: quantiteLisible(context, p, etat.quantiteBoutique(p.id, _vers!)),
                  apres: quantiteLisible(context, p, etat.quantiteBoutique(p.id, _vers!) + base),
                ),
              ],
            ],

            // 6. Motif du mouvement (affiché si écart)
            if (motifs.isNotEmpty && (op != OperationStock.inventaire || (ecart != null && !ecart.estNul))) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                op == OperationStock.inventaire ? 'Raison de l\'écart constaté' : l10n.comReason,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in motifs)
                    ChoiceChip(
                      label: Text(libelleMotif(l10n, m)),
                      selected: _motif == m,
                      onSelected: (_) => setState(() => _motif = m),
                    ),
                ],
              ),
            ],

            // 7. Note facultative
            const SizedBox(height: AppSpacing.sm),
            if (_noteVisible)
              TextField(
                controller: _note,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l10n.comNoteOptional,
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                ),
              )
            else
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => setState(() => _noteVisible = true),
                  icon: const Icon(Icons.notes_rounded, size: 18),
                  label: Text(l10n.comAddNote),
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // 8. Bouton Principal de Validation
            FilledButton(
              key: const Key('operation-valider'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: op == OperationStock.sortie ? AppColors.warning : AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: valide && !_enCours ? _valider : null,
              child: _enCours
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(bouton, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte élégante pour visualiser l'écart d'inventaire
class _CarteEcartInventaire extends StatelessWidget {
  const _CarteEcartInventaire({
    required this.avant,
    required this.apres,
    required this.ecart,
    required this.uniteBase,
  });

  final String avant;
  final String apres;
  final Qte ecart;
  final String uniteBase;

  @override
  Widget build(BuildContext context) {
    final bool nul = ecart.estNul;
    final bool positif = ecart.estPositif;
    final couleurEcart = nul ? AppColors.muted : (positif ? AppColors.green : AppColors.warning);
    final signe = positif ? '+' : (ecart.estNegatif ? '−' : '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: couleurEcart.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleurEcart.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                nul ? Icons.check_circle_outline : (positif ? Icons.trending_up_rounded : Icons.trending_down_rounded),
                color: couleurEcart,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nul ? 'Aucun écart (Stock conforme)' : 'Écart d\'inventaire : $signe${formatQte(context, ecart.absolue)} $uniteBase',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: couleurEcart),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Avant inventaire', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(avant, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.ink)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.muted, size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Nouveau stock réel', style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(apres, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: couleurEcart)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String libelleMotif(AppLocalizations l10n, MotifMouvement m) => switch (m) {
      MotifMouvement.achat => l10n.comReasonPurchase,
      MotifMouvement.retour => l10n.comReasonReturn,
      MotifMouvement.ajustement => l10n.comReasonAdjustment,
      MotifMouvement.vente => l10n.comReasonSale,
      MotifMouvement.perte => l10n.comReasonLoss,
      MotifMouvement.casse => l10n.comReasonBreakage,
      MotifMouvement.transfert => l10n.comReasonTransfer,
      MotifMouvement.erreurComptage => l10n.comReasonCountError,
      MotifMouvement.manquant => l10n.comReasonMissing,
      MotifMouvement.autre => l10n.comReasonOther,
    };

class _Alerte extends StatelessWidget {
  const _Alerte(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('operation-insuffisant'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.negativeSoft, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.negative),
            const SizedBox(width: 10),
            Expanded(
              child: Text(texte, style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
