import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../providers/finance_dashboard_providers.dart';

/// Page de consultation et d'export du Rapport Financier DUBAGEST.
class FinanceRapportPage extends ConsumerWidget {
  const FinanceRapportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final format = NumberFormat.decimalPattern('fr');
    final dataAsync = ref.watch(financeDashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport Financier'),
        actions: [
          IconButton(
            tooltip: 'Imprimer / Exporter PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Génération du rapport PDF en cours...')),
              );
            },
          ),
          IconButton(
            tooltip: 'Partager',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Partage du rapport financier...')),
              );
            },
          ),
        ],
      ),
      body: ResponsiveBody(
        maxWidth: 960,
        child: AsyncValueView(
          value: dataAsync,
          data: (data) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // En-tête officiel du rapport
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'DUBAGEST',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF01226C),
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Généré le ${DateFormat('dd/MM/yyyy HH:mm', 'fr').format(DateTime.now())}',
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Rapport d’Activité & Synthèse Financière',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Période : ${data.periode.libelleCourt()} (${DateFormat('dd/MM/yyyy').format(data.plageDates.debut)} au ${DateFormat('dd/MM/yyyy').format(data.plageDates.fin)})',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Tableau récapitulatif
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
                        '1. Indicateurs de Performance',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LigneRapport(
                        label: 'Chiffre d’affaires total',
                        valeur: '${format.format(data.chiffreAffaires.valeurActuelle)} FCFA',
                        gras: true,
                      ),
                      if (data.margeCommerce != null) ...[
                        _LigneRapport(
                          label: '  • Coût des marchandises vendues (COGS)',
                          valeur: '-${format.format(data.margeCommerce!.coutMarchandisesVendues)} FCFA',
                        ),
                        _LigneRapport(
                          label: '  • Marge brute réalisée',
                          valeur: '${format.format(data.margeCommerce!.margeBrute)} FCFA (${data.margeCommerce!.tauxMargePourcent.toStringAsFixed(1)} %)',
                        ),
                      ],
                      _LigneRapport(
                        label: 'Dépenses opérationnelles de fonctionnement',
                        valeur: '-${format.format(data.totalDepenses)} FCFA',
                      ),
                      const Divider(height: 24),
                      _LigneRapport(
                        label: 'Résultat net estimé',
                        valeur: '${format.format(data.resultatEstime.valeurActuelle)} FCFA',
                        gras: true,
                        couleurValeur: data.resultatEstime.valeurActuelle >= 0 ? AppColors.positive : AppColors.negative,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Synthèse Trésorerie & Engagements
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
                        '2. Trésorerie & Engagements',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _LigneRapport(
                        label: 'Trésorerie disponible (Caisses et comptes)',
                        valeur: '${format.format(data.tresorerieDisponible.valeurActuelle)} FCFA',
                        gras: true,
                      ),
                      _LigneRapport(
                        label: 'Créances clients à recouvrer',
                        valeur: '${format.format(data.aRecevoir.valeurActuelle)} FCFA',
                        couleurValeur: AppColors.gold,
                      ),
                      _LigneRapport(
                        label: 'Dettes fournisseurs à régler',
                        valeur: '${format.format(data.aPayer.valeurActuelle)} FCFA',
                        couleurValeur: AppColors.negative,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LigneRapport extends StatelessWidget {
  const _LigneRapport({
    required this.label,
    required this.valeur,
    this.gras = false,
    this.couleurValeur,
  });

  final String label;
  final String valeur;
  final bool gras;
  final Color? couleurValeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: gras ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 13,
              fontWeight: gras ? FontWeight.w800 : FontWeight.w600,
              color: couleurValeur ?? AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
