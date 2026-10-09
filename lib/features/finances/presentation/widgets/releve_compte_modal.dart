import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/dossier_dette.dart';
import 'finances_widgets.dart';

/// Modal de visualisation et partage d'un relevé de compte financier.
class ReleveCompteModal extends ConsumerWidget {
  const ReleveCompteModal({super.key, required this.dossier});

  final DossierDette dossier;

  static Future<void> show(BuildContext context, DossierDette dossier) {
    return showDialog(
      context: context,
      builder: (_) => ReleveCompteModal(dossier: dossier),
    );
  }

  String _genererTexteReleve(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.read(deviseProvider);
    final buffer = StringBuffer();

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('DUBAGEST — RELEVÉ DE COMPTE');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('Personne : ${dossier.nomAffiche}');
    if (dossier.telephone != null) buffer.writeln('Téléphone : ${dossier.telephone}');
    buffer.writeln('Date du relevé : ${l10n.date(DateTime.now())}');
    buffer.writeln();
    buffer.writeln('SITUATION FINANCIÈRE :');
    buffer.writeln('• Total initial dû  : ${l10n.montant(dossier.totalDu, devise)}');
    buffer.writeln('• Total déjà réglé  : ${l10n.montant(dossier.totalPaye, devise)}');
    buffer.writeln('• SOLDE RESTANT NET : ${l10n.montant(dossier.reste, devise)}');
    if (dossier.totalEnRetard > 0) {
      buffer.writeln('• Dont en retard    : ${l10n.montant(dossier.totalEnRetard, devise)}');
    }
    buffer.writeln();

    if (dossier.engagements.isNotEmpty) {
      buffer.writeln('DÉTAIL DES OPÉRATIONS EN COURS :');
      for (final s in dossier.engagements.where((x) => !x.engagement.annule)) {
        final e = s.engagement;
        final ech = e.echeance != null ? ' (Échéance: ${l10n.date(e.echeance!)})' : '';
        buffer.writeln('- ${e.libelle} : ${l10n.montant(e.montantTotal, devise)} | Reste : ${l10n.montant(s.reste, devise)}$ech');
      }
      buffer.writeln();
    }

    if (dossier.paiements.isNotEmpty) {
      buffer.writeln('HISTORIQUE DES PAIEMENTS :');
      for (final pSuivi in dossier.paiements.take(10)) {
        final p = pSuivi.paiement;
        final mode = l10n.modePaiement(p.mode);
        buffer.writeln('✓ ${l10n.date(p.datePaiement)} : +${l10n.montant(p.montant, devise)} ($mode)');
      }
      buffer.writeln();
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('DUBAGEST — La gestion simple de votre activité');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final devise = ref.watch(deviseProvider);
    final texte = _genererTexteReleve(context, ref);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.green, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Text('Relevé de compte', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Aperçu visuel synthétique
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dossier.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    if (dossier.telephone != null)
                      Text(dossier.telephone!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Solde restant :', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          l10n.montant(dossier.reste, devise),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF01226C)),
                        ),
                      ],
                    ),
                    if (dossier.totalEnRetard > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('En retard :', style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.w600, fontSize: 12)),
                          Text(
                            l10n.montant(dossier.totalEnRetard, devise),
                            style: const TextStyle(color: AppColors.negative, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Prévisualisation du texte
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  texte,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF01226C),
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: texte));
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Relevé copié dans le presse-papier !')),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copier / Partager'),
        ),
      ],
    );
  }
}
