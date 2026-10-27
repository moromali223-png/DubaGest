import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/pdf/document_pdf_generator.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/resultat_encaissement_loyer.dart';

/// Modal / Dialogue moderne affichant la confirmation d'encaissement et le reçu
/// avec options d'impression immédiate, partage de PDF et envoi sur WhatsApp.
class RecuLoyerConfirmationDialog extends ConsumerWidget {
  const RecuLoyerConfirmationDialog({
    super.key,
    required this.resultat,
    this.onNouveauPaiement,
  });

  final ResultatEncaissementLoyer resultat;
  final VoidCallback? onNouveauPaiement;

  static Future<void> afficher(
    BuildContext context, {
    required ResultatEncaissementLoyer resultat,
    VoidCallback? onNouveauPaiement,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RecuLoyerConfirmationDialog(
        resultat: resultat,
        onNouveauPaiement: onNouveauPaiement,
      ),
    );
  }

  Future<void> _imprimerRecu(BuildContext context, Document? doc) async {
    if (doc == null) return;
    try {
      final bytes = await genererDocumentPdf(doc);
      await Printing.layoutPdf(
        name: '${doc.numero}.pdf',
        onLayout: (_) async => bytes,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'impression : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _partagerPdf(BuildContext context, Document? doc) async {
    if (doc == null) return;
    try {
      final bytes = await genererDocumentPdf(doc);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${doc.numero}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _partagerSurWhatsApp(BuildContext context, String devise) async {
    final doc = resultat.document;
    final telLocataire = (doc?.contenu['locataire_telephone'] as String?) ?? '';
    final cleanTel = telLocataire.replaceAll(RegExp(r'[^0-9+]'), '');

    final titre = resultat.estSoldeTotal ? 'Quittance de loyer' : 'Reçu d\'acompte de loyer';
    final numero = doc?.numero ?? 'REC-${DateTime.now().year}';
    final locataireNom = doc?.contenu['locataire_nom'] ?? 'Locataire';
    final bienNom = doc?.contenu['bien_nom'] ?? 'Bien immobilier';
    final periode = resultat.echeancePrincipale.periodeLibelle;
    final fmt = NumberFormat('#,##0', 'fr');
    final montant = '${fmt.format(resultat.montantTotalVerse)} $devise';
    final reste = '${fmt.format(resultat.resteTotalDu)} $devise';
    final dateStr = DateFormat('dd/MM/yyyy à HH:mm').format(resultat.datePaiement);

    final modeLibelle = switch (resultat.modePaiement.code.toUpperCase()) {
      'ESPECES' => 'Espèces',
      'ORANGEMONEY' || 'ORANGE_MONEY' => 'Orange Money',
      'MOOVMONEY' || 'MOOV_MONEY' => 'Moov Money',
      'VIREMENT' => 'Virement bancaire',
      'CHEQUE' => 'Chèque',
      _ => resultat.modePaiement.code,
    };

    final refInfo = resultat.referencePaiement != null && resultat.referencePaiement!.isNotEmpty
        ? '\n🔖 *Réf. Transaction :* ${resultat.referencePaiement}'
        : '';

    final statutLigne = resultat.estSoldeTotal
        ? '✅ *Statut :* Loyer soldé en totalité'
        : '⏳ *Statut :* Paiement partiel (Reste à payer : $reste)';

    final message = '''
🏢 *DubaGest — $titre*
━━━━━━━━━━━━━━━━━━━━━━
📄 *N° :* $numero
👤 *Locataire :* $locataireNom
🏠 *Bien :* $bienNom
📅 *Période :* $periode
💰 *Montant reçu :* $montant
💳 *Mode :* $modeLibelle$refInfo
$statutLigne
🗓️ *Date :* $dateStr
━━━━━━━━━━━━━━━━━━━━━━
_Document officiel généré par DubaGest._
''';

    final uri = cleanTel.isNotEmpty
        ? Uri.parse('https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible d\'ouvrir WhatsApp. Vérifiez votre installation.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final entrepriseNom = ctx?.entreprise?.nom ?? 'DubaGest';
    final fmt = NumberFormat('#,##0', 'fr');

    final doc = resultat.document;
    final bienNom = doc?.contenu['bien_nom'] ?? 'Bien immobilier';
    final locataireNom = doc?.contenu['locataire_nom'] ?? 'Locataire';
    final numero = doc?.numero ?? 'REC-2026';
    final estSolde = resultat.estSoldeTotal;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge de succès & Titre
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: estSolde
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    estSolde ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded,
                    color: estSolde ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  estSolde ? 'Encaissement confirmé !' : 'Acompte enregistré !',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
              ),
              Center(
                child: Text(
                  estSolde
                    ? 'Le loyer a été intégralement soldé. La quittance est prête.'
                    : 'Le montant a été crédité. Un solde reste dû sur cette échéance.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 18),

              // CARTE REÇU PROFESSIONNEL
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: estSolde
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête du reçu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entrepriseNom,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                estSolde ? 'QUITTANCE DE LOYER' : 'REÇU D\'ACOMPTE DE LOYER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: estSolde ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            numero,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppColors.border),

                    // Grille des informations
                    _buildRow('Locataire :', locataireNom, gras: true),
                    const SizedBox(height: 6),
                    _buildRow('Bien immobilier :', bienNom),
                    const SizedBox(height: 6),
                    _buildRow('Période :', resultat.echeancePrincipale.periodeLibelle),
                    const SizedBox(height: 6),
                    _buildRow('Date encaissement :', DateFormat('dd/MM/yyyy HH:mm').format(resultat.datePaiement)),
                    const SizedBox(height: 6),
                    _buildRow('Mode de paiement :', switch (resultat.modePaiement.code.toUpperCase()) {
                      'ESPECES' => 'Espèces',
                      'ORANGEMONEY' || 'ORANGE_MONEY' => 'Orange Money',
                      'MOOVMONEY' || 'MOOV_MONEY' => 'Moov Money',
                      'VIREMENT' => 'Virement bancaire',
                      'CHEQUE' => 'Chèque',
                      _ => resultat.modePaiement.code,
                    }),
                    if (resultat.referencePaiement != null && resultat.referencePaiement!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildRow('Réf. transaction :', resultat.referencePaiement!),
                    ],
                    const Divider(height: 20, color: AppColors.border),

                    // Montants
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Montant reçu :', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                          '${fmt.format(resultat.montantTotalVerse)} $devise',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Solde restant dû :', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                        Text(
                          resultat.resteTotalDu == 0
                              ? '0 $devise (Soldé)'
                              : '${fmt.format(resultat.resteTotalDu)} $devise',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: resultat.resteTotalDu == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),

                    // Détail des allocations multi-périodes si > 1
                    if (resultat.allocations.length > 1) ...[
                      const Divider(height: 20, color: AppColors.border),
                      const Text(
                        'Ventilation sur plusieurs échéances :',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      const SizedBox(height: 6),
                      for (final a in resultat.allocations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('• ${a.periodeLibelle}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                              Text(
                                '${fmt.format(a.montantAffecte)} $devise (${a.estSolde ? 'Soldé' : 'Partiel'})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ACTIONS PRINCIPALES : IMPRIMER & PARTAGER (WHATSAPP / PDF)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18, color: AppColors.ink),
                      label: const Text('Imprimer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      onPressed: () => _imprimerRecu(context, doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.primary),
                      label: const Text('Partager PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      onPressed: () => _partagerPdf(context, doc),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: () => _partagerSurWhatsApp(context, devise),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // BOUTON FERMER OU NOUVEAU PAIEMENT
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onNouveauPaiement?.call();
                },
                child: const Text('Terminer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool gras = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: gras ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
