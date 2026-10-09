import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/commerce.dart';
import '../commerce_providers.dart';
import '../pages/ventes_page.dart' show indexRecus;
import '../recus/filtre_recus.dart';
import '../recus/recu_vente.dart';
import '../recus/recu_vente_widgets.dart';
import 'commerce_widgets.dart';

/// Accueil : résumé des reçus du jour (pas de longue liste) et les trois
/// dernières ventes, avec un accès direct à tous les reçus.
class ResumeRecusAccueil extends ConsumerWidget {
  const ResumeRecusAccueil({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (!ref.watch(droitsCommerceProvider).voirVentes) return const SizedBox.shrink();
    final etat = ref.watch(etatCommerceProvider).value;
    if (etat == null) return const SizedBox.shrink();
    final boutiques = ref.watch(boutiquesVisiblesProvider);
    final index = indexRecus(ref, etat, boutiques);
    if (index.isEmpty) return const SizedBox.shrink();

    final aujourdhui = filtrerRecus(index, const FiltreRecus())
        .where((r) => r.statut != StatutRecu.annule)
        .toList();
    final total = aujourdhui.fold(0, (t, r) => t + r.vente.total);
    final recents = filtrerRecus(index, const FiltreRecus(periode: PeriodeRecus.tout)).take(3).toList();
    final locale = Localizations.localeOf(context).toString();

    Widget chiffre(IconData icone, String libelle, String valeur) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icone, size: 20, color: CouleursRecu.bleu),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(valeur, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              Text(libelle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
          ),
        );

    return Column(
      key: const Key('accueil-recus'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Row(children: [
          Expanded(child: Text(l10n.rcpPeriodToday, style: Theme.of(context).textTheme.titleMedium)),
          TextButton(
            onPressed: () => context.push(Routes.historiqueVentes),
            child: Text('${l10n.rcpSeeAll} →'),
          ),
        ]),
        Row(children: [
          chiffre(Icons.payments_outlined, l10n.rcpSales, montant(context, ref, total)),
          const SizedBox(width: AppSpacing.sm),
          chiffre(Icons.receipt_long_outlined, l10n.rcpTitle, '${aujourdhui.length}'),
          if (boutiques.length > 1) ...[
            const SizedBox(width: AppSpacing.sm),
            chiffre(Icons.storefront_outlined, l10n.rcpShops, '${boutiques.length}'),
          ],
        ]),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.rcpLatest, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
        const SizedBox(height: AppSpacing.xs),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, r) in recents.indexed) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                dense: true,
                onTap: () => context.push(Routes.vente(r.vente.id)),
                leading: const Icon(Icons.receipt_long_rounded, color: CouleursRecu.bleu),
                title: Text(
                    r.vente.numero ??
                        numeroRecu(
                          r.vente.dateCommerciale ?? jourCommercial(r.vente.date),
                          r.vente.poste ?? '',
                          r.vente.sequence ?? 1,
                        ),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text([
                  r.client ?? l10n.rcpCounterCustomer,
                  if (boutiques.length > 1) r.boutique,
                  DateFormat.Hm(locale).format(r.vente.date.toLocal()),
                ].join(' · ')),
                trailing: Text(montant(context, ref, r.vente.total),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ],
    );
  }
}
