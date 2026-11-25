import 'dart:async';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

class DocumentExportPlatform {
  static Future<void> telechargerFichier(
    Uint8List bytes,
    String nomFichier, {
    String mimeType = 'application/pdf',
  }) async {
    await Printing.sharePdf(bytes: bytes, filename: nomFichier);
  }

  static Future<void> ouvrirFichier(
    Uint8List bytes, {
    String? nomFichier,
    String mimeType = 'application/pdf',
  }) async {
    await Printing.layoutPdf(
      name: nomFichier ?? 'document.pdf',
      onLayout: (_) => bytes,
    );
  }

  static Future<bool> partagerFichier({
    required Uint8List bytes,
    required String nomFichier,
    required String titre,
    String? texte,
  }) async {
    try {
      await Printing.sharePdf(bytes: bytes, filename: nomFichier);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> imprimer({
    required FutureOr<Uint8List> Function(PdfPageFormat) onLayout,
    required String nomDocument,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    await Printing.layoutPdf(
      name: nomDocument,
      format: format,
      onLayout: onLayout,
    );
  }

  static Future<void> ouvrirWhatsApp({
    required String numero,
    required String message,
  }) async {
    final cleanPhone = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(message);
    final urlString = cleanPhone.isNotEmpty
        ? 'https://wa.me/$cleanPhone?text=$encoded'
        : 'https://api.whatsapp.com/send?text=$encoded';
    final uri = Uri.parse(urlString);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
