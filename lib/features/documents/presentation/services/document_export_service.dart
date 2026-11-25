import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/document.dart';
import 'document_export_io.dart'
    if (dart.library.js_interop) 'document_export_web.dart';

/// Service unifié d'exportation, de téléchargement, d'impression et de partage
/// des documents professionnels DubaGest (PWA Web, iOS Safari, Android, Desktop).
class DocumentExportService {
  const DocumentExportService._();

  /// Téléchargement direct du PDF sans dépendance bloquante à un iframe navigateur.
  /// Résout les restrictions de Safari iPhone grâce au déclencheur Blob Web.
  static Future<void> telechargerPdf({
    required Uint8List bytes,
    required String nomFichier,
  }) async {
    final nom = nomFichier.endsWith('.pdf') ? nomFichier : '$nomFichier.pdf';
    await DocumentExportPlatform.telechargerFichier(bytes, nom);
  }

  /// Ouvre le PDF généré dans un nouvel onglet ou visualiseur natif.
  static Future<void> ouvrirPdf({
    required Uint8List bytes,
    String? nomFichier,
  }) async {
    await DocumentExportPlatform.ouvrirFichier(bytes, nomFichier: nomFichier);
  }

  /// Impression standard ou ticket thermique.
  static Future<void> imprimerPdf({
    required FutureOr<Uint8List> Function(PdfPageFormat) onLayout,
    required String nomDocument,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    await DocumentExportPlatform.imprimer(
      onLayout: onLayout,
      nomDocument: nomDocument,
      format: format,
    );
  }

  /// Partage natif via la Web Share API (sur iPhone Safari & Android PWA)
  /// avec repli automatique vers le téléchargement si non disponible.
  static Future<bool> partagerNatif({
    required Uint8List bytes,
    required String nomFichier,
    required String titre,
    String? texte,
  }) async {
    final nom = nomFichier.endsWith('.pdf') ? nomFichier : '$nomFichier.pdf';
    return await DocumentExportPlatform.partagerFichier(
      bytes: bytes,
      nomFichier: nom,
      titre: titre,
      texte: texte,
    );
  }

  /// Partage direct vers WhatsApp avec message pré-rempli et téléchargement du PDF.
  static Future<void> partagerWhatsApp({
    required String numero,
    required String message,
    Uint8List? bytesPdf,
    String? nomFichier,
  }) async {
    // Si un fichier est fourni, on le met immédiatement à disposition de l'utilisateur
    if (bytesPdf != null && nomFichier != null) {
      await telechargerPdf(bytes: bytesPdf, nomFichier: nomFichier);
    }
    await DocumentExportPlatform.ouvrirWhatsApp(
      numero: numero,
      message: message,
    );
  }

  /// Construit un texte de message WhatsApp courtois et professionnel pour tout document.
  static String preparerMessageDocument(Document d, {String devise = 'FCFA'}) {
    final c = d.contenu;
    final entreprise = (c['entreprise'] as Map?)?['nom'] ?? 'DubaGest';
    final typeStr = switch (d.type) {
      TypeDocument.facture => 'Facture',
      TypeDocument.devis => 'Devis Proforma',
      TypeDocument.recu => 'Reçu de paiement',
      TypeDocument.avoir => 'Note de crédit / Avoir',
      TypeDocument.bonCommande => 'Bon de commande',
      TypeDocument.bonTravail => 'Ordre de travail / Intervention',
      TypeDocument.quittance => 'Quittance de loyer',
      TypeDocument.contrat => 'Contrat',
    };

    return 'Bonjour,\n\n'
        'Veuillez trouver ci-joint votre $typeStr N° ${d.numero} émis par $entreprise '
        'pour un montant de ${d.montant} $devise.\n\n'
        'Merci pour votre confiance.\n'
        '-- $entreprise';
  }

  /// Affiche une feuille d'actions unifiée pour le partage et l'export du document.
  static Future<void> afficherOptionsExport(
    BuildContext context, {
    required String titre,
    required String nomFichier,
    required Future<Uint8List> Function() genererPdf,
    String? contactTelephone,
    String? messageWhatsApp,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ExportBottomSheet(
        titre: titre,
        nomFichier: nomFichier,
        genererPdf: genererPdf,
        contactTelephone: contactTelephone,
        messageWhatsApp: messageWhatsApp,
        format: format,
      ),
    );
  }
}

class _ExportBottomSheet extends StatefulWidget {
  const _ExportBottomSheet({
    required this.titre,
    required this.nomFichier,
    required this.genererPdf,
    this.contactTelephone,
    this.messageWhatsApp,
    this.format = PdfPageFormat.a4,
  });

  final String titre;
  final String nomFichier;
  final Future<Uint8List> Function() genererPdf;
  final String? contactTelephone;
  final String? messageWhatsApp;
  final PdfPageFormat format;

  @override
  State<_ExportBottomSheet> createState() => _ExportBottomSheetState();
}

class _ExportBottomSheetState extends State<_ExportBottomSheet> {
  bool _enCours = false;
  Uint8List? _cachedBytes;

  Future<Uint8List> _obtenirOctets() async {
    if (_cachedBytes != null) return _cachedBytes!;
    setState(() => _enCours = true);
    try {
      final b = await widget.genererPdf();
      _cachedBytes = b;
      return b;
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, color: AppColors.green, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.nomFichier,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_enCours)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Option 1 : Téléchargement PDF
            _BoutonAction(
              icone: Icons.file_download_rounded,
              couleurIcone: AppColors.green,
              titre: 'Télécharger le PDF',
              sousTitre: 'Fichier PDF officiel haute définition',
              onTap: () async {
                Navigator.of(context).pop();
                final bytes = await _obtenirOctets();
                await DocumentExportService.telechargerPdf(
                  bytes: bytes,
                  nomFichier: widget.nomFichier,
                );
              },
            ),

            // Option 2 : Partager WhatsApp
            _BoutonAction(
              icone: Icons.chat_rounded,
              couleurIcone: const Color(0xFF25D366),
              titre: 'Partager sur WhatsApp',
              sousTitre: widget.contactTelephone != null && widget.contactTelephone!.isNotEmpty
                  ? 'Envoyer à ${widget.contactTelephone}'
                  : 'Message récapitulatif & transmission du document',
              onTap: () async {
                Navigator.of(context).pop();
                final bytes = await _obtenirOctets();
                await DocumentExportService.partagerWhatsApp(
                  numero: widget.contactTelephone ?? '',
                  message: widget.messageWhatsApp ?? 'Veuillez trouver ci-joint votre document.',
                  bytesPdf: bytes,
                  nomFichier: widget.nomFichier,
                );
              },
            ),

            // Option 3 : Partage natif (iOS / Android / Web Share API)
            _BoutonAction(
              icone: Icons.share_rounded,
              couleurIcone: AppColors.primary,
              titre: 'Partager via le menu du téléphone',
              sousTitre: 'E-mail, Bluetooth, AirDrop, Messages...',
              onTap: () async {
                Navigator.of(context).pop();
                final bytes = await _obtenirOctets();
                await DocumentExportService.partagerNatif(
                  bytes: bytes,
                  nomFichier: widget.nomFichier,
                  titre: widget.titre,
                  texte: widget.messageWhatsApp,
                );
              },
            ),

            // Option 4 : Imprimer
            _BoutonAction(
              icone: Icons.print_rounded,
              couleurIcone: AppColors.ink,
              titre: 'Imprimer',
              sousTitre: 'Imprimante connectée ou réseau (A4 / A5)',
              onTap: () async {
                Navigator.of(context).pop();
                await DocumentExportService.imprimerPdf(
                  onLayout: (_) => _obtenirOctets(),
                  nomDocument: widget.nomFichier,
                  format: widget.format,
                );
              },
            ),

            // Option 5 : Visualiser / Ouvrir dans le navigateur
            _BoutonAction(
              icone: Icons.open_in_new_rounded,
              couleurIcone: AppColors.muted,
              titre: 'Ouvrir dans un nouvel onglet',
              sousTitre: 'Visualisation directe en plein écran',
              onTap: () async {
                Navigator.of(context).pop();
                final bytes = await _obtenirOctets();
                await DocumentExportService.ouvrirPdf(
                  bytes: bytes,
                  nomFichier: widget.nomFichier,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonAction extends StatelessWidget {
  const _BoutonAction({
    required this.icone,
    required this.couleurIcone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
  });

  final IconData icone;
  final Color couleurIcone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: couleurIcone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icone, color: couleurIcone, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sousTitre,
                      style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
