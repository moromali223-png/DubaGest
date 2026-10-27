import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/prestation.dart';
import '../pdf/devis_services_pdf.dart';
import '../services_providers.dart';
import '../widgets/prestation_photos_section.dart';

/// Fiche détaillée d'un devis : Chiffrage, aperçu PDF pro, partage WhatsApp & conversion 1-clic.
class DevisDetailsPage extends ConsumerStatefulWidget {
  const DevisDetailsPage({super.key, required this.devisId});
  final String devisId;

  @override
  ConsumerState<DevisDetailsPage> createState() => _DevisDetailsPageState();
}

class _DevisDetailsPageState extends ConsumerState<DevisDetailsPage> {
  bool _enConversion = false;

  void _partagerDevisWhatsApp(DevisPrestation devis) {
    final ctx = ref.read(contexteActifProvider);
    final entrepriseNom = ctx?.entreprise?.nom ?? 'DUBAGEST';
    final contact = devis.contactId != null ? ref.read(contactProvider(devis.contactId!)).value : null;

    final lignesTexte = devis.lignes
        .map((l) => '• ${l.libelle} (${l.quantite}x) : ${l.totalLigne} FCFA')
        .join('\n');

    final validiteStr = devis.dateValidite != null
        ? DateFormat('dd/MM/yyyy').format(devis.dateValidite!)
        : '30 jours';

    final message = '''
📄 *PROPOSITION TARIFAIRE / DEVIS — $entrepriseNom*
━━━━━━━━━━━━━━━━━━━━━
🔖 *Devis N° :* ${devis.numero}
📋 *Objet :* ${devis.titre}
👤 *Destinataire :* ${contact?.nomAffiche ?? "Client"}
📅 *Date d'émission :* ${DateFormat('dd/MM/yyyy').format(devis.dateEmission)}
⏳ *Validité de l'offre :* Jusqu'au $validiteStr

📝 *Détail des prestations :*
$lignesTexte

${devis.remise > 0 ? "🏷️ *Remise :* ${devis.remise} FCFA\n" : ""}💰 *TOTAL NET :* ${devis.total} FCFA

${devis.conditions != null && devis.conditions!.isNotEmpty ? "📌 *Conditions :* ${devis.conditions}\n" : ""}
_Pour valider cette proposition, merci de nous confirmer votre accord._
_${entrepriseNom}_
''';

    final tel = contact?.whatsapp ?? contact?.telephone ?? '';
    final cleanTel = tel.replaceAll(RegExp(r'\D'), '');

    final uri = cleanTel.length >= 6
        ? Uri.parse('https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _ouvrirApercuPdf(DevisPrestation devis) {
    final ctx = ref.read(contexteActifProvider);
    final contact = devis.contactId != null ? ref.read(contactProvider(devis.contactId!)).value : null;
    final logo = ref.read(logoEntrepriseProvider).value;

    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('Devis ${devis.numero} — Aperçu & Impression'),
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: PdfPreview(
            build: (_) => genererDevisPdf(
              devis,
              entreprise: ctx?.entreprise,
              client: contact,
              logo: logo,
            ),
            pdfFileName: '${devis.numero}.pdf',
            allowPrinting: true,
            allowSharing: true,
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devisListAsync = ref.watch(devisServicesProvider);
    final droits = ref.watch(droitsServicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail du devis'),
        actions: const [
          SyncStatusButton(),
        ],
      ),
      body: AsyncValueView<List<DevisPrestation>>(
        value: devisListAsync,
        onRetry: () => ref.invalidate(devisServicesProvider),
        data: (list) {
          final devis = list.where((d) => d.id == widget.devisId).firstOrNull;
          if (devis == null) {
            return const Center(child: Text('Devis introuvable'));
          }

          final contact = devis.contactId != null
              ? ref.watch(contactProvider(devis.contactId!)).value
              : null;

          final (Color statutCouleur, String statutLibelle) = switch (devis.statut) {
            StatutDevis.brouillon => (AppColors.muted, 'Brouillon'),
            StatutDevis.envoye => (const Color(0xFF0284C7), 'Envoyé au client'),
            StatutDevis.accepte => (AppColors.green, 'Accepté'),
            StatutDevis.refuse => (AppColors.negative, 'Refusé'),
            StatutDevis.expire => (const Color(0xFFEA580C), 'Expiré'),
            StatutDevis.converti => (const Color(0xFF7C3AED), '✓ Converti en prestation'),
          };

          return ResponsiveBody(
            maxWidth: 820,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. En-tête Devis & Montant
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  devis.numero,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.muted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  devis.titre,
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
                                ),
                                if (devis.description != null && devis.description!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      devis.description!,
                                      style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                montant(context, ref, devis.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                  color: AppColors.ink,
                                ),
                              ),
                              if (devis.remise > 0)
                                Text(
                                  'Remise : ${montant(context, ref, devis.remise)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: statutCouleur.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statutLibelle,
                              style: TextStyle(color: statutCouleur, fontWeight: FontWeight.w800, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Émis le ${DateFormat('dd/MM/yyyy').format(devis.dateEmission)}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Barre d'Actions & Partage PDF / WhatsApp
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Actions & Partage du document', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.green,
                              minimumSize: const Size(0, 40),
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: const Text('Aperçu & Impression PDF'),
                            onPressed: () => _ouvrirApercuPdf(devis),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                            icon: const Icon(Icons.share_outlined, size: 18),
                            label: const Text('Partager WhatsApp'),
                            onPressed: () => _partagerDevisWhatsApp(devis),
                          ),
                          if (droits.peutCreerPrestations && devis.statut != StatutDevis.converti)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                minimumSize: const Size(0, 40),
                              ),
                              icon: _enConversion
                                  ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.bolt_rounded, size: 18),
                              label: const Text('Convertir en prestation'),
                              onPressed: _enConversion ? null : () => _convertirEnPrestation(devis.id),
                            ),
                          if (droits.peutModifierDevis && devis.statut != StatutDevis.accepte && devis.statut != StatutDevis.converti)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                              icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.green),
                              label: const Text('Marquer accepté', style: TextStyle(color: AppColors.green)),
                              onPressed: () => _changerStatut(devis.id, StatutDevis.accepte),
                            ),
                          if (droits.peutModifierDevis && devis.statut != StatutDevis.refuse && devis.statut != StatutDevis.converti)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                              icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.negative),
                              label: const Text('Marquer refusé', style: TextStyle(color: AppColors.negative)),
                              onPressed: () => _changerStatut(devis.id, StatutDevis.refuse),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Lignes chiffrées du Devis
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prestations chiffrées', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 10),
                      for (final l in devis.lignes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(l.libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                        ),
                                        if (l.estConsommable) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text('📦 Pièce stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text('${l.quantite} × ${montant(context, ref, l.prixUnitaire)}',
                                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              Text(
                                montant(context, ref, l.totalLigne),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total net du devis', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(
                            montant(context, ref, devis.total),
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.ink),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Contact & Destinataire
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Client / Destinataire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (contact != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                          title: Text(contact.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(contact.telephone ?? 'Sans numéro de téléphone'),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Client prospect (non enregistré)', style: TextStyle(color: AppColors.muted)),
                        ),
                      if (devis.dateValidite != null) ...[
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.hourglass_bottom_rounded, size: 16, color: AppColors.muted),
                            const SizedBox(width: 6),
                            Text(
                              'Offre valable jusqu\'au ${DateFormat('dd/MM/yyyy').format(devis.dateValidite!)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Photos & Croquis attachés
                PrestationPhotosSection(
                  photos: devis.photos,
                  onPhotosChanged: (photos) {
                    final maj = devis.copyWith(photos: photos);
                    ref.read(servicesRepositoryProvider).modifierDevis(maj);
                    ref.invalidate(devisServicesProvider);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changerStatut(String id, StatutDevis statut) async {
    try {
      await ref.read(gererServicesProvider).changerStatutDevis(id, statut);
      ref.invalidate(devisServicesProvider);
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _convertirEnPrestation(String id) async {
    setState(() => _enConversion = true);
    try {
      final p = await ref.read(gererServicesProvider).convertirDevisEnPrestation(id);
      ref.invalidate(devisServicesProvider);
      ref.invalidate(prestationsProvider);
      if (mounted) {
        showMessageSnackBar(context, 'Prestation générée avec succès !');
        context.push('/services/prestations/${p.id}');
      }
    } catch (e) {
      if (mounted) showFailureSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _enConversion = false);
    }
  }
}
