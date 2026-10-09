import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/prestation.dart';

enum ModeleRappel {
  rendezVous('Rappel de RDV / Intervention'),
  termine('Matériel prêt / Travail terminé'),
  solde('Relance de règlement'),
  personnalise('Message libre');

  const ModeleRappel(this.libelle);
  final String libelle;
}

/// Dialogue intelligent de relance et rappel client (WhatsApp, SMS, Copie).
class PrestationRappelDialog extends ConsumerStatefulWidget {
  const PrestationRappelDialog({super.key, required this.prestation});
  final Prestation prestation;

  static Future<void> afficher(BuildContext context, Prestation prestation) {
    return showDialog<void>(
      context: context,
      builder: (_) => PrestationRappelDialog(prestation: prestation),
    );
  }

  @override
  ConsumerState<PrestationRappelDialog> createState() => _PrestationRappelDialogState();
}

class _PrestationRappelDialogState extends ConsumerState<PrestationRappelDialog> {
  ModeleRappel _modele = ModeleRappel.rendezVous;
  late final TextEditingController _messageController;
  late final TextEditingController _telephoneController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _telephoneController = TextEditingController();

    // Modèle par défaut selon l'état de la prestation
    if (widget.prestation.statut == StatutPrestation.terminee) {
      _modele = ModeleRappel.termine;
    } else if (widget.prestation.soldeRestant > 0 && widget.prestation.statut == StatutPrestation.livree) {
      _modele = ModeleRappel.solde;
    } else {
      _modele = ModeleRappel.rendezVous;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _genererTexte());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  void _genererTexte() {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseNom = ctx?.entreprise?.nom ?? 'DUBAGEST';
    final p = widget.prestation;
    final contact = p.contactId != null ? ref.read(contactProvider(p.contactId!)).value : null;

    if (_telephoneController.text.isEmpty && contact != null) {
      _telephoneController.text = contact.whatsapp ?? contact.telephone ?? '';
    }

    final clientNom = contact?.nomAffiche ?? 'Cher(e) client(e)';
    final echeanceStr = p.echeanceJour != null
        ? DateFormat('dd/MM/yyyy').format(p.echeanceJour!) + (p.echeanceHeure != null ? ' à ${p.echeanceHeure}' : '')
        : 'très prochainement';

    String texte = '';
    switch (_modele) {
      case ModeleRappel.rendezVous:
        texte = '''Bonjour $clientNom,

Nous vous rappelons votre rendez-vous pour l'intervention *"${p.titre}"* prévue le *$echeanceStr* chez *$entrepriseNom*.

📍 Lieu : ${p.lieu ?? 'En nos locaux'}
Pour tout empêchement ou modification, merci de nous contacter.

À très bientôt !
_${entrepriseNom}_''';
        break;

      case ModeleRappel.termine:
        texte = '''Bonjour $clientNom,

Bonne nouvelle ! Votre prestation *"${p.titre}"* est *terminée* et prête à être récupérée chez *$entrepriseNom*.

💰 Total : ${p.total} FCFA
${p.soldeRestant > 0 ? "💳 Reste à régler à la livraison : *${p.soldeRestant} FCFA*" : "✓ Facture déjà totalement réglée"}

Nous sommes à votre disposition pour la remise.
_${entrepriseNom}_''';
        break;

      case ModeleRappel.solde:
        texte = '''Bonjour $clientNom,

Sauf erreur de notre part, un solde de *${p.soldeRestant} FCFA* reste en attente de règlement concernant la prestation *"${p.titre}"* effectuée par *$entrepriseNom*.

Merci de bien vouloir procéder à la régularisation dès que possible.

Cordialement,
_${entrepriseNom}_''';
        break;

      case ModeleRappel.personnalise:
        if (_messageController.text.isEmpty) {
          texte = 'Bonjour $clientNom,\n\nConcernant votre intervention "${p.titre}"...\n\n_${entrepriseNom}_';
        } else {
          return;
        }
        break;
    }

    setState(() {
      _messageController.text = texte;
    });
  }

  void _envoyerWhatsApp() {
    final tel = _telephoneController.text.replaceAll(RegExp(r'\D'), '');
    final msg = _messageController.text.trim();
    final uri = tel.length >= 6
        ? Uri.parse('https://wa.me/$tel?text=${Uri.encodeComponent(msg)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _envoyerSms() {
    final tel = _telephoneController.text.trim();
    final msg = _messageController.text.trim();
    final uri = Uri.parse('sms:$tel?body=${Uri.encodeComponent(msg)}');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _copierMessage() {
    Clipboard.setData(ClipboardData(text: _messageController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copié dans le presse-papiers')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prestation;
    final contact = p.contactId != null ? ref.watch(contactProvider(p.contactId!)).value : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF01226C).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF01226C), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Envoyer un rappel / relance',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink),
                          ),
                          Text(
                            p.titre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
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

                // Sélection du modèle
                const Text('Type de rappel :', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ModeleRappel.values.map((m) {
                    final selected = _modele == m;
                    return ChoiceChip(
                      label: Text(m.libelle, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      selected: selected,
                      selectedColor: const Color(0xFF01226C),
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.ink),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _modele = m);
                          _genererTexte();
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Champ Téléphone / Destinataire
                TextField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Numéro de téléphone / WhatsApp',
                    hintText: 'Ex. +225 0700000000',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    helperText: contact != null ? 'Client : ${contact.nomAffiche}' : 'Client comptoir / sans fiche liée',
                  ),
                ),
                const SizedBox(height: 12),

                // Zone de texte modifiable
                TextField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Contenu du message',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                const SizedBox(height: 18),

                // Boutons d'action
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        minimumSize: const Size(0, 42),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      label: const Text('WhatsApp'),
                      onPressed: _envoyerWhatsApp,
                    ),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 42),
                      ),
                      icon: const Icon(Icons.sms_outlined, size: 18),
                      label: const Text('SMS'),
                      onPressed: _envoyerSms,
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copier'),
                      onPressed: _copierMessage,
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
