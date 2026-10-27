import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/commerce.dart';
import 'commerce_widgets.dart';

/// Quantité + unité (« 3 cartons ») avec l'équivalent affiché en direct
/// (« = 120 pièces »). L'utilisateur ne fait jamais le calcul.
class ChampQuantite extends StatefulWidget {
  const ChampQuantite({
    super.key,
    required this.produit,
    required this.onChanged,
    this.uniteInitiale,
    this.quantiteInitiale,
    this.label,
    this.autofocus = false,
    this.zeroAutorise = false,
    this.afficherSelecteurUnites = true,
    this.champKey,
  });

  final Produit produit;
  final void Function(Qte? quantite, UniteVente unite) onChanged;
  final UniteVente? uniteInitiale;
  final Qte? quantiteInitiale;
  final String? label;
  final bool autofocus;

  /// Inventaire : 0 est une quantité comptée valable.
  final bool zeroAutorise;
  final bool afficherSelecteurUnites;
  final Key? champKey;

  @override
  State<ChampQuantite> createState() => _ChampQuantiteState();
}

class _ChampQuantiteState extends State<ChampQuantite> {
  late UniteVente _unite = widget.uniteInitiale ?? widget.produit.uniteDeBase;
  late final _texte = TextEditingController(
    text: widget.quantiteInitiale == null ? '' : _brut(widget.quantiteInitiale!),
  );

  @override
  void didUpdateWidget(ChampQuantite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.uniteInitiale != null && widget.uniteInitiale != oldWidget.uniteInitiale) {
      _unite = widget.uniteInitiale!;
    }
  }

  static String _brut(Qte q) => q.estEntier ? '${q.brut ~/ Qte.echelle}' : q.valeur.toString();

  Qte? get _quantite => Qte.lire(_texte.text);

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  void _notifier() => widget.onChanged(_quantite, _unite);

  void _ajouter(Qte pas) {
    final q = (_quantite ?? Qte.zero) + pas;
    _texte.text = _brut(q);
    setState(() {});
    _notifier();
  }

  String? _erreur(BuildContext context) {
    final l10n = context.l10n;
    final q = _quantite;
    if (_texte.text.trim().isEmpty) return null;
    if (q == null || (!widget.zeroAutorise && !q.estPositif)) return l10n.comQuantityInvalid;
    final base = q.fois(_unite.facteur);
    final p = widget.produit;
    if (!p.venteFractionnee && !base.estEntier) return l10n.comFractionNotAllowed(p.uniteBase);
    if (p.venteFractionnee && !base.estMultipleDe(p.pasMinimum)) {
      return l10n.comFractionStep(formatQte(context, p.pasMinimum), p.uniteBase);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.produit;
    final q = _quantite;
    final base = q?.fois(_unite.facteur);
    final equivalent = base != null && !_unite.estBase && base.estPositif ? '= ${qteUnite(context, base, p.uniteBase)}' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: widget.champKey,
          controller: _texte,
          autofocus: widget.autofocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,/ ]'))],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: widget.label ?? l10n.comQuantity,
            hintText: '0',
            suffixText: nomUnite(context, _unite.nom, q ?? Qte.zero),
            errorText: _erreur(context),
            helperText: equivalent,
            helperStyle: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          onChanged: (_) {
            setState(() {});
            _notifier();
          },
        ),
        if (widget.afficherSelecteurUnites && p.aPlusieursUnites) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final u in p.toutesUnites)
                ChoiceChip(
                  key: Key('unite-${u.nom}'),
                  label: Text(u.estBase ? u.nom : '${u.nom} (${formatQte(context, u.facteur)} ${p.uniteBase})'),
                  selected: u.id == _unite.id,
                  onSelected: (_) {
                    setState(() => _unite = u);
                    _notifier();
                  },
                ),
            ],
          ),
        ],
        if (p.venteFractionnee) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final (texte, valeur) in [('¼', 2500), ('½', 5000), ('¾', 7500), ('1', 10000)])
                ActionChip(
                  label: Text('+ $texte'),
                  onPressed: () => _ajouter(Qte(valeur)),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
