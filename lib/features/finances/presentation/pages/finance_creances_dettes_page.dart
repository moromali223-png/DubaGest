import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/finance_dashboard_providers.dart';

/// Page d'analyse des Créances clients & Dettes fournisseurs.
class FinanceCreancesDettesPage extends ConsumerWidget {
  const FinanceCreancesDettesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat.decimalPattern('fr');
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créances & Dettes'),
      ),
      body: ResponsiveBody(
        maxWidth: 960,
        child: AsyncValueView(
          value: dataAsync,
          data: (data) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Cartes de synthèse
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('À recevoir (Clients)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.goldDark)),
                            const SizedBox(height: 4),
                            Text(
                              '${format.format(data.aRecevoir.valeurActuelle)} FCFA',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text('${data.nombreClientsDebiteurs} clients concernés', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.negative.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('À payer (Fournisseurs)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.negative)),
                            const SizedBox(height: 4),
                            Text(
                              '${format.format(data.aPayer.valeurActuelle)} FCFA',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
                            ),
                            const SizedBox(height: 2),
                            Text('${data.nombreFournisseursCreanciers} fournisseurs concernés', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Taux de recouvrement
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Taux de recouvrement client',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '${data.recouvrement.tauxPourcent.toStringAsFixed(1)} %',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.green),
                          ),
                          const Spacer(),
                          Text(
                            'Encaissé : ${format.format(data.recouvrement.totalEncaisse)} / Facturé : ${format.format(data.recouvrement.totalFacture)} FCFA',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (data.recouvrement.tauxPourcent / 100).clamp(0.0, 1.0),
                          backgroundColor: AppColors.background,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.green),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Alertes Retards
                if (data.creancesEnRetard > 0 || data.dettesEnRetard > 0) ...[
                  const Text(
                    'Retards d’échéances',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (data.creancesEnRetard > 0)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        title: const Text('Créances clients en retard'),
                        subtitle: const Text('Échéances dépassées à relancer'),
                        trailing: Text(
                          '${format.format(data.creancesEnRetard)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning),
                        ),
                      ),
                    ),
                  if (data.dettesEnRetard > 0)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.error_outline_rounded, color: AppColors.negative),
                        title: const Text('Dettes fournisseurs en retard'),
                        subtitle: const Text('Paiements en attente de règlement'),
                        trailing: Text(
                          '${format.format(data.dettesEnRetard)} FCFA',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.negative),
                        ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
