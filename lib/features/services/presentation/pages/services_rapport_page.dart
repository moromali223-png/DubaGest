import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';

enum PeriodeRapportServices {
  aujourdhui('Aujourd\'hui'),
  semaine('Cette semaine'),
  mois('Ce mois-ci'),
  trimestre('Ce trimestre'),
  annee('Cette année'),
  tout('Tout l\'historique');

  const PeriodeRapportServices(this.libelle);
  final String libelle;
}

/// Tableau de bord analytique, rentabilité et rapports d'activité des services.
class ServicesRapportPage extends ConsumerStatefulWidget {
  const ServicesRapportPage({super.key});

  @override
  ConsumerState<ServicesRapportPage> createState() => _ServicesRapportPageState();
}

class _ServicesRapportPageState extends ConsumerState<ServicesRapportPage> {
  PeriodeRapportServices _periode = PeriodeRapportServices.mois;

  @override
  Widget build(BuildContext context) {
    final prestationsAsync = ref.watch(prestationsProvider);
    final devisAsync = ref.watch(devisServicesProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports & Rentabilité Services'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (toutesPrestations) {
          final tousDevis = devisAsync.value ?? const <DevisPrestation>[];

          // Filtrage par période
          final dateDebut = switch (_periode) {
            PeriodeRapportServices.aujourdhui => DateTime(now.year, now.month, now.day),
            PeriodeRapportServices.semaine => DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)),
            PeriodeRapportServices.mois => DateTime(now.year, now.month, 1),
            PeriodeRapportServices.trimestre => DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1),
            PeriodeRapportServices.annee => DateTime(now.year, 1, 1),
            PeriodeRapportServices.tout => DateTime(2000),
          };

          final prestations = toutesPrestations.where((p) {
            if (p.statut == StatutPrestation.annulee) return false;
            final d = p.dateEcheanceComplete ?? now;
            return d.isAfter(dateDebut.subtract(const Duration(seconds: 1)));
          }).toList();

          final devis = tousDevis.where((d) {
            return d.dateEmission.isAfter(dateDebut.subtract(const Duration(seconds: 1)));
          }).toList();

          // Calculs financiers
          final totalFacture = prestations.fold<int>(0, (sum, p) => sum + p.total);
          final totalEncaisse = prestations.fold<int>(0, (sum, p) => sum + p.montantRegle);
          final totalCreances = prestations.fold<int>(0, (sum, p) => sum + p.soldeRestant);

          // Ventilation Main d'œuvre vs Pièces / Consommables
          int totalMainOeuvre = 0;
          int totalPieces = 0;
          for (final p in prestations) {
            for (final l in p.lignes) {
              if (l.estConsommable) {
                totalPieces += l.totalLigne;
              } else {
                totalMainOeuvre += l.totalLigne;
              }
            }
          }

          // Statistiques d'activité
          final nbTotal = prestations.length;
          final nbTerminees = prestations.where((p) => p.statut == StatutPrestation.terminee || p.statut == StatutPrestation.livree).length;
          final nbEnCours = prestations.where((p) => p.statut == StatutPrestation.enCours).length;
          final tauxReussite = nbTotal > 0 ? ((nbTerminees / nbTotal) * 100).round() : 0;

          // Conversion des devis
          final nbDevisTotal = devis.length;
          final nbDevisAcceptes = devis.where((d) => d.statut == StatutDevis.accepte || d.statut == StatutDevis.converti).length;
          final tauxConversionDevis = nbDevisTotal > 0 ? ((nbDevisAcceptes / nbDevisTotal) * 100).round() : 0;

          return ResponsiveBody(
            maxWidth: 860,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sélecteur de période
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: PeriodeRapportServices.values.map((p) {
                      final selected = _periode == p;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(p.libelle, style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, fontSize: 12.5)),
                          selected: selected,
                          selectedColor: const Color(0xFF01226C),
                          labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink),
                          onSelected: (_) => setState(() => _periode = p),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Synthèse Financière Principale
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Performance Financière',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _KpiBox(
                              titre: 'Total Facturé',
                              valeur: montant(context, ref, totalFacture),
                              couleur: const Color(0xFF01226C),
                              icone: Icons.receipt_long_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiBox(
                              titre: 'Encaissé',
                              valeur: montant(context, ref, totalEncaisse),
                              couleur: AppColors.green,
                              icone: Icons.payments_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KpiBox(
                              titre: 'À Recouvrer',
                              valeur: montant(context, ref, totalCreances),
                              couleur: totalCreances > 0 ? AppColors.negative : AppColors.muted,
                              icone: Icons.pending_actions_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Ventilation de la Rentabilité (Main d'œuvre vs Pièces)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ventilation de la Valeur Facturée',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.handyman_rounded, size: 16, color: Color(0xFF01226C)),
                              const SizedBox(width: 6),
                              Text('Main d\'œuvre / Prestations : ${montant(context, ref, totalMainOeuvre)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF0284C7)),
                              const SizedBox(width: 6),
                              Text('Pièces stock : ${montant(context, ref, totalPieces)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: totalFacture > 0 ? (totalMainOeuvre / totalFacture).clamp(0.0, 1.0) : 0.5,
                          minHeight: 10,
                          backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.3),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF01226C)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Activité, Achèvement & Devis
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Interventions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('$nbTotal prestation${nbTotal > 1 ? "s" : ""}',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF01226C))),
                            const SizedBox(height: 6),
                            Text('$nbTerminees terminées • $nbEnCours en cours',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('Taux d\'achèvement : $tauxReussite%',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.green)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Transformation Devis', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                            const SizedBox(height: 8),
                            Text('$tauxConversionDevis%',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF7C3AED))),
                            const SizedBox(height: 6),
                            Text('$nbDevisAcceptes acceptés sur $nbDevisTotal émis',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text(nbDevisTotal > 0 ? 'Taux de concrétisation' : 'Aucun devis sur la période',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF7C3AED))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiBox extends StatelessWidget {
  const _KpiBox({
    required this.titre,
    required this.valeur,
    required this.couleur,
    required this.icone,
  });

  final String titre;
  final String valeur;
  final Color couleur;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 16, color: couleur),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: couleur),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: couleur),
          ),
        ],
      ),
    );
  }
}
