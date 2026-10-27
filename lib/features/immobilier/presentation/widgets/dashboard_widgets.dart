import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/dashboard_immobilier.dart';

/// En-tête des 4 grands indicateurs clés de performance immobilière.
class KpiImmobilierHeader extends StatelessWidget {
  const KpiImmobilierHeader({
    super.key,
    required this.data,
    required this.devise,
  });

  final DashboardImmobilierData data;
  final String devise;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            // KPI 1 : Taux d'occupation
            Expanded(
              child: _buildHeroCard(
                title: 'Taux d\'occupation',
                value: '${data.tauxOccupation.toStringAsFixed(1)} %',
                subtitle: '${data.nbBiensOccupes} sur ${data.totalBiens} biens occupés',
                icon: Icons.pie_chart_rounded,
                couleurAccent: const Color(0xFF10B981),
                progressRatio: data.tauxOccupation / 100,
              ),
            ),
            const SizedBox(width: 12),
            // KPI 2 : Recouvrement du mois
            Expanded(
              child: _buildHeroCard(
                title: 'Recouvrement mensuel',
                value: '${data.tauxRecouvrement.toStringAsFixed(1)} %',
                subtitle: context.l10n.montant(data.totalLoyersEncaissesMois, devise),
                icon: Icons.payments_rounded,
                couleurAccent: const Color(0xFF01226C),
                progressRatio: data.tauxRecouvrement / 100,
                complement: 'Reste : ${context.l10n.montant(data.totalImpayesMois, devise)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // KPI 3 : Cautions en garantie (strictement ségréguées)
            Expanded(
              child: _buildSimpleCard(
                title: 'Dépôts de garantie (Cautions)',
                value: context.l10n.montant(data.totalCautionsEnDepot, devise),
                subtitle: 'Fonds tiers sous séquestre contractuel',
                icon: Icons.savings_outlined,
                couleur: const Color(0xFFDF9540),
              ),
            ),
            const SizedBox(width: 12),
            // KPI 4 : Baux et locataires actifs
            Expanded(
              child: _buildSimpleCard(
                title: 'Parc & Locataires actifs',
                value: '${data.nbContratsActifs} bail(s) actif(s)',
                subtitle: '${data.nbLocatairesActifs} locataire(s) sous contrat',
                icon: Icons.home_work_outlined,
                couleur: const Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color couleurAccent,
    required double progressRatio,
    String? complement,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
              ),
              Icon(icon, size: 18, color: couleurAccent),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: couleurAccent),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink, fontWeight: FontWeight.w600),
          ),
          if (complement != null) ...[
            const SizedBox(height: 2),
            Text(
              complement,
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressRatio.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(couleurAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color couleur,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 18, color: couleur),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Grille des 6 entrées maîtresses du module Immobilier.
class ModuleImmobilierGrid extends StatelessWidget {
  const ModuleImmobilierGrid({
    super.key,
    required this.data,
  });

  final DashboardImmobilierData data;

  @override
  Widget build(BuildContext context) {
    final modules = [
      (
        titre: 'Biens',
        sousTitre: '${data.totalBiens} biens répertoriés',
        icone: Icons.home_work_outlined,
        couleur: const Color(0xFF01226C),
        route: Routes.immobilierBiens,
      ),
      (
        titre: 'Propriétaires',
        sousTitre: 'Bailleurs & Mandats',
        icone: Icons.badge_outlined,
        couleur: const Color(0xFF059669),
        route: Routes.immobilierProprietaires,
      ),
      (
        titre: 'Locataires',
        sousTitre: '${data.nbLocatairesActifs} locataire(s)',
        icone: Icons.family_restroom_outlined,
        couleur: const Color(0xFF2563EB),
        route: Routes.immobilierLocataires,
      ),
      (
        titre: 'Locations',
        sousTitre: '${data.nbBiensOccupes} bien(s) occupé(s)',
        icone: Icons.key_outlined,
        couleur: const Color(0xFFD97706),
        route: Routes.immobilierLocations,
      ),
      (
        titre: 'Contrats de bail',
        sousTitre: '${data.nbContratsActifs} bail(s) actif(s)',
        icone: Icons.history_edu_outlined,
        couleur: const Color(0xFF7C3AED),
        route: Routes.immobilierContrats,
      ),
      (
        titre: 'Loyers & Avis',
        sousTitre: 'Recouvrement & Quittances',
        icone: Icons.receipt_long_outlined,
        couleur: const Color(0xFFDC2626),
        route: Routes.immobilierLoyers,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: modules.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemBuilder: (context, index) {
        final m = modules[index];
        return InkWell(
          onTap: () => context.push(m.route),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: m.couleur.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m.icone, color: m.couleur, size: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  m.titre,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  m.sousTitre,
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Carte d'affichage d'une alerte métier prioritaire.
class AlerteImmobilierCard extends StatelessWidget {
  const AlerteImmobilierCard({
    super.key,
    required this.alerte,
    this.devise = 'FCFA',
  });

  final AlerteImmobilier alerte;
  final String devise;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: alerte.niveau.couleur.withValues(alpha: 0.4),
          width: alerte.niveau == NiveauAlerte.critique ? 1.5 : 1.0,
        ),
      ),
      color: alerte.niveau.couleur.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: alerte.niveau.couleur.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(alerte.type.icone, color: alerte.niveau.couleur, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          alerte.titre,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: alerte.niveau == NiveauAlerte.critique
                                ? const Color(0xFFDC2626)
                                : AppColors.ink,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: alerte.niveau.couleur.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          alerte.niveau.libelle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: alerte.niveau.couleur,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alerte.message,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink),
                  ),
                  if (alerte.actionRoute != null && alerte.actionLibelle != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: alerte.niveau.couleur,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                        label: Text(
                          alerte.actionLibelle!,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        onPressed: () => context.push(alerte.actionRoute!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Jauge de répartition visuelle du parc immobilier.
class RepartitionBiensBar extends StatelessWidget {
  const RepartitionBiensBar({super.key, required this.data});
  final DashboardImmobilierData data;

  @override
  Widget build(BuildContext context) {
    final total = data.totalBiens;
    if (total == 0) return const SizedBox.shrink();

    final ratioOccupes = data.nbBiensOccupes / total;
    final ratioDisponibles = data.nbBiensDisponibles / total;
    final ratioEnTravaux = data.nbBiensEnTravaux / total;
    final ratioReserves = data.nbBiensReserves / total;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition du parc immobilier',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (ratioOccupes > 0)
                    Expanded(flex: (ratioOccupes * 100).round(), child: Container(color: const Color(0xFF10B981))),
                  if (ratioDisponibles > 0)
                    Expanded(flex: (ratioDisponibles * 100).round(), child: Container(color: const Color(0xFF3B82F6))),
                  if (ratioReserves > 0)
                    Expanded(flex: (ratioReserves * 100).round(), child: Container(color: const Color(0xFFDF9540))),
                  if (ratioEnTravaux > 0)
                    Expanded(flex: (ratioEnTravaux * 100).round(), child: Container(color: const Color(0xFF7C3AED))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildLegend('Occupés (${data.nbBiensOccupes})', const Color(0xFF10B981)),
              _buildLegend('Disponibles (${data.nbBiensDisponibles})', const Color(0xFF3B82F6)),
              _buildLegend('Réservés (${data.nbBiensReserves})', const Color(0xFFDF9540)),
              _buildLegend('En travaux (${data.nbBiensEnTravaux})', const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
