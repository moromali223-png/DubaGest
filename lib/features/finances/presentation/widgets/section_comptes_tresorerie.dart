import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/finance_dashboard_data.dart';

/// Section "Comptes & Trésorerie Active" inspirée de la carte "CURRENT LOANS"
/// de la maquette de référence : carte épurée, compacte, avec entête déroulant
/// et vue instantanée sur la Caisse, les Créances et les Dettes.
class SectionComptesTresorerie extends StatefulWidget {
  const SectionComptesTresorerie({
    super.key,
    required this.data,
    this.devise = 'FCFA',
    this.onTapCaisse,
    this.onTapCreances,
    this.onTapDettes,
    this.onActionPlus,
  });

  final FinanceDashboardData data;
  final String devise;
  final VoidCallback? onTapCaisse;
  final VoidCallback? onTapCreances;
  final VoidCallback? onTapDettes;
  final VoidCallback? onActionPlus;

  @override
  State<SectionComptesTresorerie> createState() => _SectionComptesTresorerieState();
}

class _SectionComptesTresorerieState extends State<SectionComptesTresorerie> {
  bool _estOuvert = true;

  String _formatMontant(int montant) {
    return '${NumberFormat.decimalPattern('fr').format(montant)} ${widget.devise}';
  }

  @override
  Widget build(BuildContext context) {
    final unite = widget.devise == 'XOF' ? 'FCFA' : widget.devise;
    final treso = widget.data.tresorerieDisponible.valeurActuelle;
    final aRecevoir = widget.data.aRecevoir.valeurActuelle;
    final aPayer = widget.data.aPayer.valeurActuelle;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF223830),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête : Titre en majuscules + Chevron déroulant + Bouton Action (+)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _estOuvert = !_estOuvert),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      children: [
                        Icon(
                          _estOuvert ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                          color: const Color(0xFFA5B8B1),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'SITUATION DES COMPTES',
                          style: TextStyle(
                            color: Color(0xFFA5B8B1),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.onActionPlus != null)
                  InkWell(
                    onTap: widget.onActionPlus,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2A25),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF2E463E)),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Color(0xFF2ECC71),
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_estOuvert) ...[
            const Divider(color: Color(0xFF1F2F29), height: 1),

            // 1. Caisse & Liquidités
            _LigneCompte(
              icone: Icons.account_balance_wallet_rounded,
              iconeCouleur: const Color(0xFF2ECC71),
              titre: 'Disponibilités en Caisse',
              sousTitre: 'Trésorerie opérationnelle active',
              montantPrincipal: _formatMontant(treso),
              montantSecondaire: 'Liquidités nettes',
              secondaireCouleur: const Color(0xFF2ECC71),
              onTap: widget.onTapCaisse,
            ),

            const Divider(color: Color(0xFF1A2622), height: 1, indent: 64),

            // 2. Créances Clients (À recevoir)
            _LigneCompte(
              icone: Icons.arrow_downward_rounded,
              iconeCouleur: const Color(0xFF38BDF8),
              titre: 'Créances Clients (À recevoir)',
              sousTitre: '${widget.data.nombreClientsDebiteurs} clients débiteurs',
              montantPrincipal: _formatMontant(aRecevoir),
              montantSecondaire: widget.data.creancesEnRetard > 0
                  ? '${NumberFormat.compact(locale: 'fr').format(widget.data.creancesEnRetard)} $unite en retard'
                  : 'Échéances à jour',
              secondaireCouleur: widget.data.creancesEnRetard > 0 ? const Color(0xFFF59E0B) : const Color(0xFFA5B8B1),
              onTap: widget.onTapCreances,
            ),

            const Divider(color: Color(0xFF1A2622), height: 1, indent: 64),

            // 3. Dettes Fournisseurs (À payer)
            _LigneCompte(
              icone: Icons.arrow_upward_rounded,
              iconeCouleur: const Color(0xFFEA580C),
              titre: 'Dettes Fournisseurs (À régler)',
              sousTitre: '${widget.data.nombreFournisseursCreanciers} fournisseurs',
              montantPrincipal: _formatMontant(aPayer),
              montantSecondaire: widget.data.dettesEnRetard > 0
                  ? '${NumberFormat.compact(locale: 'fr').format(widget.data.dettesEnRetard)} $unite en retard'
                  : 'Échéances maîtrisées',
              secondaireCouleur: widget.data.dettesEnRetard > 0 ? const Color(0xFFEF4444) : const Color(0xFFA5B8B1),
              onTap: widget.onTapDettes,
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneCompte extends StatelessWidget {
  const _LigneCompte({
    required this.icone,
    required this.iconeCouleur,
    required this.titre,
    required this.sousTitre,
    required this.montantPrincipal,
    required this.montantSecondaire,
    required this.secondaireCouleur,
    this.onTap,
  });

  final IconData icone;
  final Color iconeCouleur;
  final String titre;
  final String sousTitre;
  final String montantPrincipal;
  final String montantSecondaire;
  final Color secondaireCouleur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Icône carrée arrondie (style mockup Image 2)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconeCouleur.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: iconeCouleur.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Icon(icone, color: iconeCouleur, size: 20),
            ),
            const SizedBox(width: 12),

            // Titre & sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sousTitre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFA5B8B1),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Montant & Statut
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  montantPrincipal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  montantSecondaire,
                  style: TextStyle(
                    color: secondaireCouleur,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF5A756D),
            ),
          ],
        ),
      ),
    );
  }
}
