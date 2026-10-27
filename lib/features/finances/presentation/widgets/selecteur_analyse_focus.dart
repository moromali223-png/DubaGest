import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finance_dashboard_data.dart';
import 'card_creances_dettes.dart';
import 'card_prevision_tresorerie.dart';
import 'chart_depenses_categories.dart';
import 'chart_evolution_ca.dart';

enum _OngletAnalyse {
  activite('Rythme CA', Icons.show_chart_rounded),
  creances('BFR & Dettes', Icons.balance_rounded),
  previsions('Prévisions', Icons.auto_awesome_rounded),
  depenses('Dépenses', Icons.pie_chart_outline_rounded);

  const _OngletAnalyse(this.libelle, this.icone);
  final String libelle;
  final IconData icone;
}

/// Sélecteur d'analyse focalisée.
///
/// Résout le problème du défilement infini : au lieu d'empiler 10 graphiques
/// les uns sur les autres, ce composant permet de basculer instantanément
/// entre les 4 analyses majeures (CA, BFR, Prévisions, Dépenses) sur le même
/// emplacement sans fatiguer l'utilisateur.
class SelecteurAnalyseFocus extends StatefulWidget {
  const SelecteurAnalyseFocus({
    super.key,
    required this.data,
    this.devise = 'FCFA',
    this.onTapDetailCA,
    this.onTapCreances,
    this.onTapDettes,
    this.onTapDetailCharges,
  });

  final FinanceDashboardData data;
  final String devise;
  final VoidCallback? onTapDetailCA;
  final VoidCallback? onTapCreances;
  final VoidCallback? onTapDettes;
  final VoidCallback? onTapDetailCharges;

  @override
  State<SelecteurAnalyseFocus> createState() => _SelecteurAnalyseFocusState();
}

class _SelecteurAnalyseFocusState extends State<SelecteurAnalyseFocus> {
  _OngletAnalyse _ongletActif = _OngletAnalyse.activite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sélecteur horizontal moderne (style pillules d'onglets)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final onglet in _OngletAnalyse.values) ...[
                _BoutonOnglet(
                  onglet: onglet,
                  estActif: _ongletActif == onglet,
                  onTap: () => setState(() => _ongletActif = onglet),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Contenu dynamique selon l'onglet actif (zéro défilement infini)
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(_ongletActif),
            child: switch (_ongletActif) {
              _OngletAnalyse.activite => ChartEvolutionCA(
                  serie: widget.data.serieEvolutionCA,
                  totalPeriode: widget.data.chiffreAffaires.valeurActuelle,
                  devise: widget.devise,
                  onTapDetail: widget.onTapDetailCA,
                ),
              _OngletAnalyse.creances => CardCreancesDettes(
                  aRecevoir: widget.data.aRecevoir.valeurActuelle,
                  nombreDebiteurs: widget.data.nombreClientsDebiteurs,
                  creancesEnRetard: widget.data.creancesEnRetard,
                  aPayer: widget.data.aPayer.valeurActuelle,
                  nombreCreanciers: widget.data.nombreFournisseursCreanciers,
                  dettesEnRetard: widget.data.dettesEnRetard,
                  onTapCreances: widget.onTapCreances,
                  onTapDettes: widget.onTapDettes,
                ),
              _OngletAnalyse.previsions => CardPrevisionTresorerie(
                  previsions: widget.data.previsions,
                ),
              _OngletAnalyse.depenses => ChartDepensesCategories(
                  categories: widget.data.categoriesDepenses,
                  onTapDetail: widget.onTapDetailCharges,
                ),
            },
          ),
        ),
      ],
    );
  }
}

class _BoutonOnglet extends StatelessWidget {
  const _BoutonOnglet({
    required this.onglet,
    required this.estActif,
    required this.onTap,
  });

  final _OngletAnalyse onglet;
  final bool estActif;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: estActif ? const Color(0xFF1E7E4E) : const Color(0xFF141E1B),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: estActif ? const Color(0xFF2ECC71) : const Color(0xFF223830),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                onglet.icone,
                size: 15,
                color: estActif ? Colors.white : const Color(0xFFA5B8B1),
              ),
              const SizedBox(width: 6),
              Text(
                onglet.libelle,
                style: TextStyle(
                  color: estActif ? Colors.white : const Color(0xFFA5B8B1),
                  fontSize: 12,
                  fontWeight: estActif ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
