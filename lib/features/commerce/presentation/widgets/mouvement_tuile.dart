import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import 'commerce_widgets.dart';
import 'operation_stock.dart' show libelleMotif;

(Color, IconData) visuelMouvement(MouvementStock m) => switch (m.type) {
      TypeMouvementStock.entree => (AppColors.positive, Icons.south_west_rounded),
      TypeMouvementStock.sortie => (AppColors.negative, Icons.north_east_rounded),
      TypeMouvementStock.transfertSortie || TypeMouvementStock.transfertEntree =>
        (const Color(0xFF2563EB), Icons.swap_horiz_rounded),
      TypeMouvementStock.inventaire => (AppColors.ink, Icons.fact_check_outlined),
    };

String libelleType(AppLocalizations l10n, TypeMouvementStock t) => switch (t) {
      TypeMouvementStock.entree => l10n.comTypeEntry,
      TypeMouvementStock.sortie => l10n.comTypeExit,
      TypeMouvementStock.transfertSortie => l10n.comTypeTransferOut,
      TypeMouvementStock.transfertEntree => l10n.comTypeTransferIn,
      TypeMouvementStock.inventaire => l10n.comTypeInventory,
    };

/// Une ligne du journal : « 🟢 Entrée · 100 cartons — Carreaux 40×40 ·
/// Boutique A · Achat · par Mohamed · 14:35 ».
class MouvementTuile extends ConsumerWidget {
  const MouvementTuile({super.key, required this.mouvement, this.avecProduit = true});
  final MouvementStock mouvement;
  final bool avecProduit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final m = mouvement;
    final etat = ref.watch(etatCommerceProvider).value;
    final produit = etat?.produit(m.produitId);
    final (couleur, icone) = visuelMouvement(m);
    final signe = m.delta.estNegatif ? '−' : '+';
    final transfert = etat?.transferts.where((t) => t.id == m.origineId).firstOrNull;
    final lieu = transfert != null
        ? '${nomBoutique(ref, transfert.dePerimetreId)} → ${nomBoutique(ref, transfert.versPerimetreId)}'
        : nomBoutique(ref, m.perimetreId);
    final details = [
      lieu,
      libelleMotif(l10n, m.motif),
      if (m.auteurNom != null) l10n.comBy(m.auteurNom!),
      DateFormat.Hm(Localizations.localeOf(context).toString()).format(m.date.toLocal()),
    ].join(' · ');
    final saisie = qteUnite(context, m.quantiteSaisie, m.uniteSaisie);

    return InkWell(
      onTap: avecProduit && produit != null ? () => context.push(Routes.produit(produit.id)) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (avecProduit && produit != null)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProduitImage(produit: produit, taille: 46),
                  PositionedDirectional(
                    bottom: -4,
                    end: -4,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: couleur,
                      child: Icon(icone, size: 13, color: Colors.white),
                    ),
                  ),
                ],
              )
            else
              CircleAvatar(
                radius: 20,
                backgroundColor: couleur.withValues(alpha: 0.12),
                child: Icon(icone, color: couleur, size: 20),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          avecProduit && produit != null
                              ? '${libelleType(l10n, m.type)} · ${produit.nom}'
                              : libelleType(l10n, m.type),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        m.type == TypeMouvementStock.inventaire
                            ? '$signe${produit == null ? formatQte(context, m.delta.absolue) : quantiteLisible(context, produit, m.delta.absolue)}'
                            : '$signe$saisie',
                        style: TextStyle(fontWeight: FontWeight.w800, color: couleur),
                      ),
                    ],
                  ),
                  Text(details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  if (m.note != null)
                    Text(m.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic)),
                  if (m.refuse)
                    Text(l10n.comMovementRejected,
                        style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            RecordSyncBadge(status: m.syncStatus),
          ],
        ),
      ),
    );
  }
}
