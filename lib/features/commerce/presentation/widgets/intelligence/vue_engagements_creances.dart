import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:dubagest/app/theme/app_theme.dart';
import 'package:dubagest/features/commerce/domain/entities/intelligence_commerciale_data.dart';
import 'kpi_cards_intelligence.dart';

class VueEngagementsCreances extends StatefulWidget {
  const VueEngagementsCreances({
    super.key,
    required this.clients,
    required this.fournisseurs,
  });

  final List<AnalyseClientCredit> clients;
  final List<AnalyseFournisseurDette> fournisseurs;

  @override
  State<VueEngagementsCreances> createState() => _VueEngagementsCreancesState();
}

class _VueEngagementsCreancesState extends State<VueEngagementsCreances> {
  bool _vueClients = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Créances & Engagements',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF01226C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _vueClients ? 'Suivi des créances et retards clients' : 'Engagements et dettes fournisseurs',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              // Sélecteur Bascule Clients / Fournisseurs
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TogglePill(
                      titre: 'Clients',
                      selectionne: _vueClients,
                      onTap: () => setState(() => _vueClients = true),
                    ),
                    _TogglePill(
                      titre: 'Fournisseurs',
                      selectionne: !_vueClients,
                      onTap: () => setState(() => _vueClients = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_vueClients)
            _ListeClientsCredit(clients: widget.clients)
          else
            _ListeFournisseursDette(fournisseurs: widget.fournisseurs),
        ],
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.titre,
    required this.selectionne,
    required this.onTap,
  });

  final String titre;
  final bool selectionne;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selectionne ? const Color(0xFF01226C) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          titre,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: selectionne ? FontWeight.w800 : FontWeight.w600,
            color: selectionne ? Colors.white : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _ListeClientsCredit extends StatelessWidget {
  const _ListeClientsCredit({required this.clients});
  final List<AnalyseClientCredit> clients;

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucune créance ni historique client sur la période.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clients.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (ctx, i) {
        final c = clients[i];
        final aEchu = c.creanceEchue > 0;
        final (couleurRisque, badgeRisque) = switch (c.niveauRisque) {
          'Critique' => (const Color(0xFFDC2626), 'Critique'),
          'Moyen' => (const Color(0xFFDF9540), 'Moyen'),
          _ => (const Color(0xFF1E7E4E), 'Sain'),
        };

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/contacts/${c.contactId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: couleurRisque.withValues(alpha: 0.12),
                  child: Text(
                    c.nomClient.characters.first.toUpperCase(),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: couleurRisque),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nomClient,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'CA : ${KpiCardsIntelligence.formatMontant(c.chiffreAffaires)} F',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                          const SizedBox(width: 6),
                          Text(
                            '${c.nombreAchats} achat(s)',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (c.creanceRestante > 0)
                      Text(
                        'Dû : ${KpiCardsIntelligence.formatMontant(c.creanceRestante)} F',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: aEchu ? const Color(0xFFDC2626) : const Color(0xFFDF9540),
                        ),
                      )
                    else
                      const Text(
                        'À jour',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E7E4E)),
                      ),
                    if (aEchu)
                      Text(
                        'Retard : ${c.joursRetardMax} j.',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: couleurRisque.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeRisque,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: couleurRisque),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ListeFournisseursDette extends StatelessWidget {
  const _ListeFournisseursDette({required this.fournisseurs});
  final List<AnalyseFournisseurDette> fournisseurs;

  @override
  Widget build(BuildContext context) {
    if (fournisseurs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucun engagement fournisseur enregistré.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fournisseurs.length,
      separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
      itemBuilder: (ctx, i) {
        final f = fournisseurs[i];
        final aDetteEchue = f.detteEchue > 0;
        final aDette = f.detteRestante > 0;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/contacts/${f.fournisseurId}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF01226C).withValues(alpha: 0.1),
                  child: Text(
                    f.nomFournisseur.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF01226C)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.nomFournisseur,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total achats : ${KpiCardsIntelligence.formatMontant(f.totalAchats)} F',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (aDette)
                      Text(
                        'Reste : ${KpiCardsIntelligence.formatMontant(f.detteRestante)} F',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: aDetteEchue ? const Color(0xFFDC2626) : const Color(0xFFDF9540),
                        ),
                      )
                    else
                      const Text(
                        'Soldé',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E7E4E)),
                      ),
                    if (aDetteEchue)
                      const Text(
                        'Échue !',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                      )
                    else if (f.prochaineEcheance != null)
                      Text(
                        'Échéance : ${DateFormat('dd/MM').format(f.prochaineEcheance!)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
              ],
            ),
          ),
        );
      },
    );
  }
}
