import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finances.dart';
import '../providers/finances_providers.dart';
import 'finances_widgets.dart';

/// Historique financier d'un contact (fiche contact) : ce qu'il doit, ce qui
/// lui est dû et ses derniers paiements. Rien si l'utilisateur n'y a pas accès.
class HistoriqueFinancierContact extends ConsumerWidget {
  const HistoriqueFinancierContact({super.key, required this.contactId});
  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsFinancesProvider);
    if (!droits.voirCreances && !droits.voirPaiements) return _Vide(l10n.contactHistoryEmpty);
    final etat = ref.watch(etatFinancesProvider).value;
    if (etat == null) return const SizedBox.shrink();

    var doit = 0, du = 0;
    for (final s in etat.suivis.where((s) => s.engagement.contactId == contactId)) {
      s.engagement.sens == SensEngagement.aRecevoir ? doit += s.reste : du += s.reste;
    }
    final paiements = etat.paiementsSuivis.where((p) => p.paiement.contactId == contactId).take(5).toList();
    if (doit == 0 && du == 0 && paiements.isEmpty) return _Vide(l10n.contactHistoryNone);

    return Card(
      child: Column(
        children: [
          if (doit > 0)
            ListTile(
              leading: const Icon(Icons.south_west, color: AppColors.positive),
              title: Text(l10n.contactOwesUs),
              trailing: Montant(doit),
            ),
          if (du > 0)
            ListTile(
              leading: const Icon(Icons.north_east, color: AppColors.negative),
              title: Text(l10n.contactWeOwe),
              trailing: Montant(du),
            ),
          for (final p in paiements)
            ListTile(
              dense: true,
              title: Text(l10n.modePaiement(p.paiement.mode)),
              subtitle: Text(l10n.dateTime(p.paiement.datePaiement)),
              trailing: Montant(
                p.paiement.montant,
                signe: p.paiement.sens == SensPaiement.entree,
                barre: p.annule || p.paiement.refuse,
              ),
              onTap: () => context.push(Routes.paiement(p.paiement.id)),
            ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, color: AppColors.muted),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(texte, style: const TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    ),
  );
}
