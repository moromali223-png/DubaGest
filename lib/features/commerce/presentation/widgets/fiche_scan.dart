import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'commerce_widgets.dart';
import 'operation_stock.dart';

/// Après un scan : le produit trouvé (photo, nom, stock) et les actions
/// immédiates ; un code inconnu propose de créer le produit.
Future<void> traiterCodeScanne(BuildContext context, WidgetRef ref, String code) async {
  final l10n = context.l10n;
  final etat = ref.read(etatCommerceProvider).value;
  final produit = etat?.parCodeBarres(code);
  if (produit != null) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => FicheProduitRapide(produit: produit),
    );
    return;
  }
  final droits = ref.read(droitsCommerceProvider);
  if (!droits.creerProduits) {
    signalerErreur(context, l10n.comBarcodeUnknown);
    return;
  }
  final creer = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      icon: const Icon(Icons.qr_code_2_rounded, size: 36),
      title: Text(l10n.comBarcodeUnknown),
      content: Text('${l10n.comBarcodeUnknownHint}\n\n$code', textAlign: TextAlign.center),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.commonCancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 48)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.comCreateProduct),
        ),
      ],
    ),
  );
  if (creer == true && context.mounted) await context.push(Routes.produitNouveau(codeBarres: code));
}

class FicheProduitRapide extends ConsumerWidget {
  const FicheProduitRapide({super.key, required this.produit});
  final Produit produit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatCommerceProvider).value;
    final droits = ref.watch(droitsCommerceProvider);
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final q = etat?.quantite(produit.id, boutiques) ?? Qte.zero;
    final statut = etat?.statut(produit, q) ?? StatutStock.rupture;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ProduitImage(produit: produit, taille: 84, rayon: 16),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(produit.nom, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(quantiteLisible(context, produit, q),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      StockBadge(statut: statut),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(Routes.produit(produit.id));
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(l10n.comSeeProduct),
                  ),
                ),
                if (droits.entreeSortie) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ouvrirOperationStock(context, produit: produit, operation: OperationStock.entree);
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.comAddToStock),
                    ),
                  ),
                ],
                if (droits.vendre) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(Routes.venteAvec(produit.id));
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(l10n.comSell),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
