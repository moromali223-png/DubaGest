import 'package:flutter/material.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/benefice_commerce_data.dart';

/// Modal affichant le drill-down interactif au clic sur n'importe quel indicateur financier.
class BottomSheetDetailIndicateur extends StatelessWidget {
  const BottomSheetDetailIndicateur({
    super.key,
    required this.indicateur,
    required this.etat,
  });

  final String indicateur;
  final EtatBeneficeCommerce etat;

  String _formatMontant(int montant) {
    final s = montant.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write('\u00A0');
      }
      buffer.write(s[i]);
    }
    final signe = montant < 0 ? '-' : '';
    return '$signe${buffer.toString()} FCFA';
  }

  @override
  Widget build(BuildContext context) {
    final kpi = etat.kpi;
    final treso = etat.tresorerie;

    String titre;
    Widget contenu;

    switch (indicateur) {
      case 'benefice':
        titre = 'Comprendre le calcul du Bénéfice Net';
        contenu = _buildDetailBenefice(kpi);
        break;
      case 'cogs':
        titre = 'Détail des Coûts des Marchandises (COGS)';
        contenu = _buildDetailCogs(etat);
        break;
      case 'ca':
        titre = 'Détail du Chiffre d\'Affaires';
        contenu = _buildDetailCA(kpi);
        break;
      case 'marge':
        titre = 'Détail de la Marge Brute';
        contenu = _buildDetailMarge(kpi);
        break;
      case 'depenses':
        titre = 'Détail des Dépenses Commerciales';
        contenu = _buildDetailDepenses(etat);
        break;
      case 'creances':
        titre = 'Créances clients restant dues';
        contenu = _buildDetailCreances(treso);
        break;
      case 'encaisse':
        titre = 'Encaissements réels de la période';
        contenu = _buildDetailEncaissements(treso);
        break;
      case 'decaisse':
        titre = 'Décaissements réels de la période';
        contenu = _buildDetailDecaissements(treso);
        break;
      case 'produits_sans_cout':
        titre = 'Articles sans prix d\'achat renseigné';
        contenu = _buildDetailProduitsSansCout(etat);
        break;
      default:
        titre = 'Détail de l\'indicateur';
        contenu = const Text('Aucun détail disponible');
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  titre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2522),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, size: 20, color: Color(0xFF6B7280)),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.border),
          Expanded(
            child: SingleChildScrollView(
              child: contenu,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailBenefice(KpiBeneficeCommerce kpi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LigneCalcul(
          titre: '1. Chiffre d\'affaires net',
          montant: _formatMontant(kpi.chiffreAffairesNet),
          signe: '+',
          couleur: const Color(0xFF1E7E4E),
          explication: 'Ventes commerciales validées sur la période (après déduction des remises).',
        ),
        const SizedBox(height: 10),
        _LigneCalcul(
          titre: '2. Coût des marchandises vendues (COGS)',
          montant: _formatMontant(kpi.cogs),
          signe: '-',
          couleur: const Color(0xFFD97706),
          explication: 'Coût d\'achat des articles effectivement sortis de stock lors des ventes.',
        ),
        const Divider(height: 20, color: AppColors.border),
        _LigneCalcul(
          titre: '= Marge brute commerciale',
          montant: _formatMontant(kpi.margeBrute),
          signe: '=',
          couleur: const Color(0xFF0D9488),
          explication: 'Bénéfice direct dégagé par la revente des articles (Taux : ${kpi.tauxMarge.toStringAsFixed(1)}%).',
        ),
        const SizedBox(height: 10),
        _LigneCalcul(
          titre: '3. Dépenses d\'exploitation imputables',
          montant: _formatMontant(kpi.depensesCommerciales),
          signe: '-',
          couleur: const Color(0xFFDC2626),
          explication: 'Loyers, électricité, charges courantes et frais commerciaux de la période.',
        ),
        const Divider(height: 24, thickness: 1.5, color: Color(0xFF1E7E4E)),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kpi.estBeneficiaire ? const Color(0xFFE8F5EE) : const Color(0xFFFFECEB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BÉNÉFICE NET ESTIMÉ',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A2522)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Taux net : ${kpi.tauxBeneficeNet.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kpi.estBeneficiaire ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              Text(
                _formatMontant(kpi.beneficeNetEstime),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kpi.estBeneficiaire ? const Color(0xFF1E7E4E) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCogs(EtatBeneficeCommerce etat) {
    final prods = etat.produitsRentabilite;
    if (prods.isEmpty) {
      return const Center(child: Text('Aucun article vendu sur cette période.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total du coût des marchandises : ${_formatMontant(etat.kpi.cogs)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Seul le stock vendu est déduit. Les articles encore en stock ne constituent pas une charge de la période.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        for (final p in prods) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(
                        'Qté : ${p.quantiteVendue} ${p.uniteBase} · Coût unitaire : ${p.coutAchatUnitaire != null ? _formatMontant(p.coutAchatUnitaire!) : "Non renseigné"}',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatMontant(p.cogs),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                    ),
                    Text(
                      'Marge : ${_formatMontant(p.margeBrute)}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1E7E4E)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailCA(KpiBeneficeCommerce kpi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LigneCalcul(
          titre: 'Chiffre d\'affaires brut facturé',
          montant: _formatMontant(kpi.chiffreAffairesBrut),
          signe: '',
          couleur: const Color(0xFF1E7E4E),
          explication: 'Somme brute de tous les articles facturés.',
        ),
        const SizedBox(height: 8),
        _LigneCalcul(
          titre: 'Remises commerciales accordées',
          montant: _formatMontant(kpi.remises),
          signe: '-',
          couleur: const Color(0xFFDC2626),
          explication: 'Réductions directement déduites sur les tickets.',
        ),
        const Divider(height: 20, color: AppColors.border),
        _LigneCalcul(
          titre: 'Chiffre d\'affaires net réalisé',
          montant: _formatMontant(kpi.chiffreAffairesNet),
          signe: '=',
          couleur: const Color(0xFF1E7E4E),
          explication: 'Sur ${kpi.nombreVentes} ticket(s) de caisse validé(s).',
        ),
      ],
    );
  }

  Widget _buildDetailMarge(KpiBeneficeCommerce kpi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LigneCalcul(
          titre: 'Marge brute commerciale',
          montant: _formatMontant(kpi.margeBrute),
          signe: '',
          couleur: const Color(0xFF0D9488),
          explication: 'Taux de marge brute : ${kpi.tauxMarge.toStringAsFixed(1)}% du chiffre d\'affaires net.',
        ),
        const SizedBox(height: 12),
        const Text(
          'La marge brute représente ce qu\'il vous reste après avoir payé le coût de revient des marchandises vendues pour couvrir vos frais généraux (loyers, électricité, salaires) et dégager votre bénéfice.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildDetailDepenses(EtatBeneficeCommerce etat) {
    final reps = etat.repartitionDepenses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total des charges de la période : ${_formatMontant(etat.kpi.depensesCommerciales)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 12),
        for (final item in reps) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.receipt_long, color: Color(0xFFDC2626), size: 20),
            title: Text(item.categorieNom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            trailing: Text(
              _formatMontant(item.total),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A2522)),
            ),
            subtitle: Text('${item.pourcentage.toStringAsFixed(1)}% des dépenses totales', style: const TextStyle(fontSize: 10.5)),
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }

  Widget _buildDetailCreances(TresorerieReelleCommerce treso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Montant restant à recevoir : ${_formatMontant(treso.creancesClientsRestantes)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ces créances correspondent aux ventes accordées à crédit dont le paiement n\'a pas encore été encaissé en caisse.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildDetailEncaissements(TresorerieReelleCommerce treso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total encaissé : ${_formatMontant(treso.totalEncaisse)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E7E4E)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Comprend tous les encaissements réels entrés en caisse ou compte bancaire : règlements de ventes au comptoir et remboursements de créances clients.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildDetailDecaissements(TresorerieReelleCommerce treso) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total décaissé : ${_formatMontant(treso.totalDecaisse)}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
        ),
        const SizedBox(height: 8),
        const Text(
          'Comprend tous les décaissements effectifs sortis de votre trésorerie : paiements de dépenses d\'exploitation et règlements de dettes aux fournisseurs.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildDetailProduitsSansCout(EtatBeneficeCommerce etat) {
    final sansCout = etat.produitsCoutManquant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pour obtenir un calcul de bénéfice 100% exact, renseignez le prix d\'achat de ces articles dans le catalogue.',
          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 12),
        for (final p in sansCout) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: Color(0xFFD97706), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nom, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('Unité : ${p.uniteBase}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF92400E))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LigneCalcul extends StatelessWidget {
  const _LigneCalcul({
    required this.titre,
    required this.montant,
    required this.signe,
    required this.couleur,
    required this.explication,
  });

  final String titre;
  final String montant;
  final String signe;
  final Color couleur;
  final String explication;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titre, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              Text(
                '${signe.isNotEmpty ? '$signe ' : ''}$montant',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: couleur),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(explication, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

