import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';

/// Ligne ou grille des 5 KPI majeurs de DUBAGEST.
class KpiPrincipauxRow extends StatelessWidget {
  const KpiPrincipauxRow({
    super.key,
    required this.data,
    this.onTapCA,
    this.onTapResultat,
    this.onTapTresorerie,
    this.onTapARecevoir,
    this.onTapAPayer,
    this.devise = 'FCFA',
  });

  final FinanceDashboardData data;
  final VoidCallback? onTapCA;
  final VoidCallback? onTapResultat;
  final VoidCallback? onTapTresorerie;
  final VoidCallback? onTapARecevoir;
  final VoidCallback? onTapAPayer;
  final String devise;

  @override
  Widget build(BuildContext context) {
    final formatCompact = NumberFormat.compact(locale: 'fr');
    final formatSeparateur = NumberFormat.decimalPattern('fr');

    String formaterMontant(int montant) {
      if (montant >= 1000000) {
        final millions = montant / 1000000.0;
        return '${millions.toStringAsFixed(1).replaceAll('.', ',')} M';
      }
      return formatSeparateur.format(montant);
    }

    final kpis = [
      _KpiItem(
        label: "Chiffre d'affaires",
        valeur: formaterMontant(data.chiffreAffaires.valeurActuelle),
        unite: devise,
        comparaison: data.chiffreAffaires.comparaisonValable && data.chiffreAffaires.tauxEvolution != null
            ? '${data.chiffreAffaires.estPositif ? '+' : ''}${data.chiffreAffaires.tauxEvolution!.toStringAsFixed(1)} % vs précédent'
            : null,
        comparaisonPositive: data.chiffreAffaires.estPositif,
        icone: Icons.trending_up_rounded,
        couleurAccent: AppColors.green,
        onTap: onTapCA,
      ),
      _KpiItem(
        label: 'Résultat estimé',
        valeur: formaterMontant(data.resultatEstime.valeurActuelle),
        unite: devise,
        comparaison: data.margeCommerce != null && data.margeCommerce!.tauxMargePourcent > 0
            ? 'Marge ${data.margeCommerce!.tauxMargePourcent.toStringAsFixed(1)} %'
            : (data.resultatEstime.valeurActuelle >= 0 ? 'Bénéfice estimé' : 'Déficit estimé'),
        comparaisonPositive: data.resultatEstime.valeurActuelle >= 0,
        icone: Icons.account_balance_wallet_outlined,
        couleurAccent: data.resultatEstime.valeurActuelle >= 0 ? AppColors.green : AppColors.negative,
        onTap: onTapResultat,
      ),
      _KpiItem(
        label: 'Argent disponible',
        valeur: formaterMontant(data.tresorerieDisponible.valeurActuelle),
        unite: devise,
        comparaison: 'En caisse & comptes',
        comparaisonPositive: data.tresorerieDisponible.valeurActuelle > 0,
        icone: Icons.savings_outlined,
        couleurAccent: const Color(0xFF01226C), // Bleu institutionnel Dubagest
        onTap: onTapTresorerie,
      ),
      _KpiItem(
        label: 'À recevoir',
        valeur: formaterMontant(data.aRecevoir.valeurActuelle),
        unite: devise,
        comparaison: data.nombreClientsDebiteurs > 0
            ? '${data.nombreClientsDebiteurs} client${data.nombreClientsDebiteurs > 1 ? 's' : ''}'
            : 'Aucune créance',
        alerteRetard: data.creancesEnRetard > 0
            ? '${formaterMontant(data.creancesEnRetard)} $devise en retard'
            : null,
        icone: Icons.call_received_rounded,
        couleurAccent: AppColors.gold,
        onTap: onTapARecevoir,
      ),
      _KpiItem(
        label: 'À payer',
        valeur: formaterMontant(data.aPayer.valeurActuelle),
        unite: devise,
        comparaison: data.nombreFournisseursCreanciers > 0
            ? '${data.nombreFournisseursCreanciers} fournisseur${data.nombreFournisseursCreanciers > 1 ? 's' : ''}'
            : 'Aucune dette',
        alerteRetard: data.dettesEnRetard > 0
            ? '${formaterMontant(data.dettesEnRetard)} $devise en retard'
            : null,
        icone: Icons.call_made_rounded,
        couleurAccent: AppColors.negative,
        onTap: onTapAPayer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final colonnes = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        final largeur = (constraints.maxWidth - AppSpacing.md * (colonnes - 1)) / colonnes;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final k in kpis)
              SizedBox(
                width: largeur,
                child: k,
              ),
          ],
        );
      },
    );
  }
}

class _KpiItem extends StatelessWidget {
  const _KpiItem({
    required this.label,
    required this.valeur,
    required this.unite,
    this.comparaison,
    this.comparaisonPositive = true,
    this.alerteRetard,
    required this.icone,
    required this.couleurAccent,
    this.onTap,
  });

  final String label;
  final String valeur;
  final String unite;
  final String? comparaison;
  final bool comparaisonPositive;
  final String? alerteRetard;
  final IconData icone;
  final Color couleurAccent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: couleurAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icone, size: 16, color: couleurAccent),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.border),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      valeur,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unite,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (alerteRetard != null)
                Text(
                  alerteRetard!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.negative,
                  ),
                )
              else if (comparaison != null)
                Row(
                  children: [
                    if (comparaison!.contains('%'))
                      Icon(
                        comparaisonPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12,
                        color: comparaisonPositive ? AppColors.positive : AppColors.negative,
                      ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        comparaison!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: comparaison!.contains('%')
                              ? (comparaisonPositive ? AppColors.positive : AppColors.negative)
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
