import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/prestation.dart';

/// Dialogue et fiche interactive du Bon de Prise en Charge / Ordre de Travail.
class BonPriseEnChargeDialog extends ConsumerWidget {
  const BonPriseEnChargeDialog({super.key, required this.prestation});
  final Prestation prestation;

  static Future<void> afficher(BuildContext context, Prestation prestation) {
    return showDialog<void>(
      context: context,
      builder: (_) => BonPriseEnChargeDialog(prestation: prestation),
    );
  }

  void _partagerWhatsApp(BuildContext context, WidgetRef ref, Contact? contact) {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseNom = ctx?.entreprise?.nom ?? 'DUBAGEST';
    final p = prestation;

    final lignesTexte = p.lignes
        .map((l) => '• ${l.libelle} (${l.quantite}x) : ${(l.totalLigne)} FCFA')
        .join('\n');

    final echeanceStr = p.echeanceJour != null
        ? DateFormat('dd/MM/yyyy').format(p.echeanceJour!) + (p.echeanceHeure != null ? ' à ${p.echeanceHeure}' : '')
        : 'À convenir';

    final message = '''
🛠️ *BON DE PRISE EN CHARGE — $entrepriseNom*
━━━━━━━━━━━━━━━━━━━━━
📋 *Intervention :* ${p.titre}
👤 *Client :* ${contact?.nomAffiche ?? "Client comptoir"}
📅 *Échéance prévue :* $echeanceStr
📍 *Statut :* ${p.statut.libelle}

📝 *Détail des travaux :*
$lignesTexte

💰 *Total estimé :* ${p.total} FCFA
💵 *Acompte réglé :* ${p.montantRegle} FCFA
💳 *Solde à la livraison :* ${p.soldeRestant} FCFA

${p.description != null && p.description!.isNotEmpty ? "🔍 *Diagnostic / Notes :* ${p.description}\n" : ""}
_Merci pour votre confiance !_
''';

    final tel = contact?.whatsapp ?? contact?.telephone ?? '';
    final cleanTel = tel.replaceAll(RegExp(r'\D'), '');

    final uri = cleanTel.length >= 6
        ? Uri.parse('https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = prestation;
    final ctx = ref.watch(contexteActifProvider);
    final entreprise = ctx?.entreprise;
    final contact = p.contactId != null ? ref.watch(contactProvider(p.contactId!)).value : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // En-tête
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF01226C),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.handyman_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entreprise?.nom ?? 'DUBAGEST',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF01226C)),
                        ),
                        const Text(
                          'ORDRE DE TRAVAIL & BON DE PRISE EN CHARGE',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.muted, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Réf & Titre
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titre,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink),
                    ),
                    if (p.description != null && p.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(p.description!, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Infos Client & Échéance
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('CLIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          contact?.nomAffiche ?? 'Client comptoir',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        if (contact?.telephone != null)
                          Text(contact!.telephone!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ÉCHÉANCE PRÉVUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          p.echeanceJour != null
                              ? DateFormat('dd/MM/yyyy').format(p.echeanceJour!)
                              : 'Non définie',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        if (p.echeanceHeure != null)
                          Text('Heure : ${p.echeanceHeure}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Détail des Lignes
              const Text('DÉSIGNATION DES TRAVAUX & PIÈCES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.muted)),
              const SizedBox(height: 6),
              for (final l in p.lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${l.quantite} × ${l.libelle}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        montant(context, ref, l.totalLigne),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Totaux
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total intervention', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(montant(context, ref, p.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF01226C))),
                ],
              ),
              if (p.montantRegle > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Acompte versé', style: TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w600)),
                    Text(montant(context, ref, p.montantRegle), style: const TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
              if (p.soldeRestant > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Reste à régler à la livraison', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFFDF9540))),
                    ),
                    const SizedBox(width: 8),
                    Text(montant(context, ref, p.soldeRestant), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFFDF9540))),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: () => _partagerWhatsApp(context, ref, contact),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Fermer'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
