import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/finances.dart';
import '../providers/finances_providers.dart';
import 'finances_widgets.dart';

/// Élément unifié pour l'affichage des derniers flux.
class _OperationFlux {
  const _OperationFlux({
    required this.id,
    required this.date,
    required this.titre,
    required this.sousTitre,
    required this.montant,
    required this.estEntree,
    required this.mode,
  });

  final String id;
  final DateTime date;
  final String titre;
  final String sousTitre;
  final int montant;
  final bool estEntree;
  final ModePaiement? mode;
}

/// Section des derniers flux financiers et opérations récentes.
///
/// Reproduit la section "Today's Workouts" du mockup sous forme de journal
/// des dernières opérations réelles (encaissements, dépenses, mouvements de caisse).
class SectionDerniersFlux extends ConsumerWidget {
  const SectionDerniersFlux({
    super.key,
    this.onVoirTout,
  });

  final VoidCallback? onVoirTout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = ref.watch(etatFinancesProvider).value;
    final devise = ref.watch(deviseProvider);
    final unite = devise == 'XOF' ? 'FCFA' : devise;
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};

    if (etat == null) return const SizedBox.shrink();

    // Consolidation des dernières opérations
    final operations = <_OperationFlux>[];

    // 1. Paiements (hors transferts et annulations)
    for (final p in etat.paiements) {
      if (p.refuse || p.estTransfert || p.estAnnulation) continue;
      final contactNom = p.contactId != null ? contacts[p.contactId]?.nomAffiche : null;
      final titre = contactNom != null
          ? (p.sens == SensPaiement.entree ? 'Client $contactNom' : 'Fournisseur $contactNom')
          : (p.reference?.isNotEmpty == true ? p.reference! : (p.sens == SensPaiement.entree ? 'Encaissement' : 'Décaissement'));

      final sousTitre = '${_modeNom(p.mode)} • ${p.sens == SensPaiement.entree ? 'Validé' : 'Réglé'}';

      operations.add(_OperationFlux(
        id: p.id,
        date: p.datePaiement,
        titre: titre,
        sousTitre: sousTitre,
        montant: p.montant,
        estEntree: p.sens == SensPaiement.entree,
        mode: p.mode,
      ));
    }

    // 2. Dépenses (si pas déjà sous forme de paiement listé)
    for (final d in etat.depenses) {
      if (d.refusee || d.annulee || d.payeeImmediatement) continue;
      operations.add(_OperationFlux(
        id: d.id,
        date: d.dateDepense,
        titre: d.libelle,
        sousTitre: d.beneficiaire != null ? 'À : ${d.beneficiaire}' : 'Charge d’exploitation',
        montant: d.montant,
        estEntree: false,
        mode: d.mode,
      ));
    }

    // Tri par date décroissante
    operations.sort((a, b) => b.date.compareTo(a.date));
    final operationsAffichees = operations.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En-tête : Titre + Lien "Tout voir"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'Derniers Flux & Opérations',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (onVoirTout != null)
              TextButton(
                onPressed: onVoirTout,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Tout voir',
                  style: TextStyle(
                    color: Color(0xFF2ECC71),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        if (operationsAffichees.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: const Color(0xFF141E1B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF243B34)),
            ),
            child: const Center(
              child: Text(
                'Aucune opération récente enregistrée',
                style: TextStyle(color: Color(0xFFA5B8B1), fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          )
        else
          for (final op in operationsAffichees) ...[
            _CarteOperation(op: op, unite: unite),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  static String _modeNom(ModePaiement mode) => switch (mode) {
    ModePaiement.especes => 'Espèces',
    ModePaiement.mobileMoney => 'Mobile Money',
    ModePaiement.carte => 'Carte bancaire',
    ModePaiement.virement => 'Virement',
    ModePaiement.cheque => 'Chèque',
    ModePaiement.autre => 'Autre mode',
  };
}

class _CarteOperation extends StatelessWidget {
  const _CarteOperation({required this.op, required this.unite});

  final _OperationFlux op;
  final String unite;

  String _formatHeureDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) {
      return DateFormat('HH:mm').format(dt);
    }
    return DateFormat('d MMM', 'fr').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final montantTexte = NumberFormat.decimalPattern('fr').format(op.montant);
    final montantSigne = op.estEntree ? '+ $montantTexte' : '- $montantTexte';
    final montantCouleur = op.estEntree ? const Color(0xFF2ECC71) : const Color(0xFFEA580C);
    final iconeCouleur = op.estEntree ? const Color(0xFF2ECC71) : const Color(0xFFEA580C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141E1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF223830),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icône dans un conteneur arrondi
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconeCouleur.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconeCouleur.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Icon(
              op.estEntree ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: iconeCouleur,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Titre et sous-titre
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  op.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  op.sousTitre,
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
          // Montant et Heure
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$montantSigne $unite',
                style: TextStyle(
                  color: montantCouleur,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatHeureDate(op.date),
                    style: const TextStyle(
                      color: Color(0xFF718B82),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Color(0xFF5A756D),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
