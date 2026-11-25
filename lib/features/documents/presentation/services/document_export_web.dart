import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

class DocumentExportPlatform {
  static Future<void> telechargerFichier(
    Uint8List bytes,
    String nomFichier, {
    String mimeType = 'application/pdf',
  }) async {
    final jsArray = bytes.toJS;
    final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    final a = web.document.createElement('a') as web.HTMLAnchorElement;
    a.href = url;
    a.download = nomFichier;
    a.style.display = 'none';
    web.document.body?.appendChild(a);
    a.click();
    a.remove();
    // Laisser un délai à Safari iOS pour finaliser le buffer de téléchargement avant révocation
    Future<void>.delayed(const Duration(seconds: 15), () {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    });
  }

  static Future<void> ouvrirFichier(
    Uint8List bytes, {
    String? nomFichier,
    String mimeType = 'application/pdf',
  }) async {
    final jsArray = bytes.toJS;
    final blob = web.Blob([jsArray].toJS, web.BlobPropertyBag(type: mimeType));
    final url = web.URL.createObjectURL(blob);
    web.window.open(url, '_blank');
    Future<void>.delayed(const Duration(seconds: 60), () {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {}
    });
  }

  static Future<bool> partagerFichier({
    required Uint8List bytes,
    required String nomFichier,
    required String titre,
    String? texte,
  }) async {
    try {
      final jsArray = bytes.toJS;
      final file = web.File(
        [jsArray].toJS,
        nomFichier,
        web.FilePropertyBag(type: 'application/pdf'),
      );
      final shareData = web.ShareData(
        title: titre,
        text: texte ?? '',
        files: [file].toJS,
      );
      await web.window.navigator.share(shareData).toDart;
      return true;
    } catch (_) {
      // Repli immédiat pour Safari iOS ou navigateurs sans Web Share API fichiers :
      // Déclenche le téléchargement du PDF pour ne jamais bloquer l'utilisateur
      await telechargerFichier(bytes, nomFichier);
      return false;
    }
  }

  static Future<void> imprimer({
    required FutureOr<Uint8List> Function(PdfPageFormat) onLayout,
    required String nomDocument,
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    try {
      await Printing.layoutPdf(
        name: nomDocument,
        format: format,
        onLayout: onLayout,
      );
    } catch (_) {
      // Sur certains navigateurs PWA iOS où Printing.layoutPdf échoue
      final octets = await onLayout(format);
      await ouvrirFichier(octets, nomFichier: nomDocument);
    }
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
