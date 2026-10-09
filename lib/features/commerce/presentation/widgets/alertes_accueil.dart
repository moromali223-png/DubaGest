import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'commerce_widgets.dart';

/// Alertes de stock de l'accueil : les photos des produits concernés, pour
/// reconnaître d'un coup d'œil ce qu'il faut racheter.
List<Widget> alertesStockAccueil(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  if (!ref.watch(droitsCommerceProvider).voirStock) return const [];
  final etat = ref.watch(etatCommerceProvider).value;
  if (etat == null) return const [];
  final boutiques = ref.watch(boutiquesVisiblesProvider);
  final aSurveiller = etat.aSurveiller(boutiques);
  final ruptures = [for (final p in aSurveiller) if (etat.statutDans(p, boutiques) == StatutStock.rupture) p];
  final faibles = [for (final p in aSurveiller) if (etat.statutDans(p, boutiques) == StatutStock.faible) p];
  return [
    if (ruptures.isNotEmpty)
      _AlerteStock(
        produits: ruptures,
        titre: l10n.comWatchOut(ruptures.length),
        couleur: AppColors.negative,
        onTap: () => context.push(Routes.stockFiltre(StatutStock.rupture)),
      ),
    if (faibles.isNotEmpty)
      _AlerteStock(
        produits: faibles,
        titre: l10n.comWatchLow(faibles.length),
        couleur: AppColors.warning,
        onTap: () => context.push(Routes.stockFiltre(StatutStock.faible)),
      ),
  ];
}

class _AlerteStock extends StatelessWidget {
  const _AlerteStock({required this.produits, required this.titre, required this.couleur, required this.onTap});
  final List<Produit> produits;
  final String titre;
  final Color couleur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final noms = produits.take(3).map((p) => p.nom).join(', ');
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      onTap: onTap,
      leading: SizedBox(
        width: 64,
        height: 44,
        child: Stack(
          children: [
            for (final (i, p) in produits.take(3).indexed)
              PositionedDirectional(
                start: i * 10.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ProduitImage(produit: p, taille: 40, rayon: 8),
                ),
              ),
          ],
        ),
      ),
      title: Text(titre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: couleur)),
      subtitle: Text(noms,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: AppColors.muted)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
    );
  }
}
