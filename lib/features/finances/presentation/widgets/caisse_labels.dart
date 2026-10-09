import 'package:flutter/material.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/caisse_tresorerie_models.dart';
import '../../domain/entities/finances.dart';
import 'finances_widgets.dart';

/// Libellés de la Caisse (traduits) : le domaine ne porte aucun texte.
extension CaisseLabels on AppLocalizations {
  String filtrePeriode(FiltrePeriode f) => switch (f) {
    FiltrePeriode.aujourdhui => periodToday,
    FiltrePeriode.hier => periodYesterday,
    FiltrePeriode.cetteSemaine => periodThisWeek,
    FiltrePeriode.ceMois => periodThisMonth,
    FiltrePeriode.cetteAnnee => periodThisYear,
    FiltrePeriode.tout => periodAll,
  };

  String origineMouvement(OrigineMouvement o) => switch (o) {
    OrigineMouvement.vente => cashSrcSale,
    OrigineMouvement.paiementClient => cashSrcCustomerPayment,
    OrigineMouvement.prestation => cashSrcService,
    OrigineMouvement.loyer => cashSrcRent,
    OrigineMouvement.achat => cashSrcPurchase,
    OrigineMouvement.paiementFournisseur => cashSrcSupplierPayment,
    OrigineMouvement.depense => cashSrcExpense,
    OrigineMouvement.apport => cashNatureContribution,
    OrigineMouvement.retrait => cashNatureWithdrawal,
    OrigineMouvement.transfert => cashNatureTransfer,
    OrigineMouvement.remboursement => cashNatureRefund,
    OrigineMouvement.ajustement => cashNatureAdjustment,
    OrigineMouvement.autre => cashNatureOther,
  };
}

IconData iconeOrigine(OrigineMouvement o) => switch (o) {
  OrigineMouvement.vente => Icons.shopping_bag_outlined,
  OrigineMouvement.paiementClient => Icons.person_outline,
  OrigineMouvement.prestation => Icons.design_services_outlined,
  OrigineMouvement.loyer => Icons.home_work_outlined,
  OrigineMouvement.achat => Icons.inventory_2_outlined,
  OrigineMouvement.paiementFournisseur => Icons.local_shipping_outlined,
  OrigineMouvement.depense => Icons.receipt_long_outlined,
  OrigineMouvement.apport => Icons.savings_outlined,
  OrigineMouvement.retrait => Icons.outbox_outlined,
  OrigineMouvement.transfert => Icons.swap_horiz_rounded,
  OrigineMouvement.remboursement => Icons.replay_rounded,
  OrigineMouvement.ajustement => Icons.tune_rounded,
  OrigineMouvement.autre => Icons.more_horiz_rounded,
};

IconData iconeMode(ModePaiement m) => switch (m) {
  ModePaiement.especes => Icons.payments_outlined,
  ModePaiement.mobileMoney => Icons.phone_android_outlined,
  ModePaiement.carte => Icons.credit_card_outlined,
  ModePaiement.virement => Icons.account_balance_outlined,
  ModePaiement.cheque => Icons.description_outlined,
  ModePaiement.autre => Icons.more_horiz_rounded,
};

/// Peu de couleurs, toujours accompagnées d'un nom et d'une icône.
Color couleurMode(ModePaiement m) => switch (m) {
  ModePaiement.especes => AppColors.green,
  ModePaiement.mobileMoney => AppColors.gold,
  ModePaiement.carte => AppColors.ink,
  ModePaiement.virement => AppColors.goldDark,
  ModePaiement.cheque => AppColors.muted,
  ModePaiement.autre => AppColors.border,
};

/// Une même teinte par sens, plus ou moins soutenue selon le rang.
Color couleurRang(int rang, {required bool entree}) {
  final base = entree ? AppColors.positive : AppColors.negative;
  const alphas = [1.0, 0.75, 0.55, 0.4, 0.3];
  return base.withValues(alpha: alphas[rang.clamp(0, alphas.length - 1)]);
}

/// Montant masquable (écran visible par plusieurs personnes).
class MontantMasquable extends StatelessWidget {
  const MontantMasquable(this.valeur, {super.key, required this.masque, this.style, this.signe});
  final int valeur;
  final bool masque;
  final TextStyle? style;
  final bool? signe;

  @override
  Widget build(BuildContext context) =>
      masque ? Text('• • • • •', style: style) : Montant(valeur, style: style, signe: signe);
}
