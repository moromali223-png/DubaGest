import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../app/localization/l10n.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../domain/entities/document.dart';

/// Polices embarquées (hors-ligne) : latin + arabe, licence OFL.
class PolicesPdf {
  PolicesPdf._(this.latin, this.latinGras, this.arabe, this.arabeGras);

  final pw.Font latin;
  final pw.Font latinGras;
  final pw.Font arabe;
  final pw.Font arabeGras;

  static PolicesPdf? _cache;

  static Future<PolicesPdf> charger() async {
    if (_cache case final p?) return p;
    Future<pw.Font> f(String nom) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$nom.ttf'));
    return _cache = PolicesPdf._(
      await f('NotoSans-Regular'),
      await f('NotoSans-Bold'),
      await f('NotoSansArabic-Regular'),
      await f('NotoSansArabic-Bold'),
    );
  }
}

/// Reçu de paiement en PDF, dans la langue du document (figée à l'émission).
/// [annule] : le paiement a été annulé depuis — le reçu porte un tampon.
/// [logo] : logo de l'entreprise (copie de l'appareil), en tête du reçu.
Future<Uint8List> genererRecuPdf(Document d, {required bool annule, PolicesPdf? polices, Uint8List? logo}) async {
  final p = polices ?? await PolicesPdf.charger();
  // La langue du document peut différer de celle de l'interface.
  await initializeDateFormatting(d.langue);
  final l = lookupAppLocalizations(Locale(d.langue));
  final arabe = d.langue == 'ar';
  final c = d.contenu;
  final entreprise = (c['entreprise'] as Map?)?.cast<String, dynamic>() ?? const {};
  final contact = (c['contact'] as Map?)?.cast<String, dynamic>();
  final paiement = (c['paiement'] as Map?)?.cast<String, dynamic>() ?? const {};
  final lignes = ((c['lignes'] as List?) ?? const []).cast<Map>();
  final devise = entreprise['devise'] as String? ?? 'XOF';
  final unite = devise == 'XOF' ? 'FCFA' : devise;
  final nombres = NumberFormat.decimalPattern(d.langue);
  String montant(Object? v) => '${nombres.format((v as num?) ?? 0)} $unite';
  final dateDoc = DateFormat.yMMMMd(d.langue).add_Hm().format(d.date.toLocal());

  final theme = pw.ThemeData.withFont(
    base: arabe ? p.arabe : p.latin,
    bold: arabe ? p.arabeGras : p.latinGras,
    fontFallback: arabe ? [p.latin, p.latinGras] : [p.arabe, p.arabeGras],
  );
  const vert = PdfColor.fromInt(0xFF1A7F45);
  const encre = PdfColor.fromInt(0xFF1B2622);
  const gris = PdfColor.fromInt(0xFF56675F);

  pw.Widget info(String label, String? valeur) => valeur == null || valeur.isEmpty
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(children: [
            pw.SizedBox(width: 110, child: pw.Text(label, style: const pw.TextStyle(color: gris, fontSize: 9))),
            pw.Expanded(child: pw.Text(valeur, style: const pw.TextStyle(fontSize: 10))),
          ]),
        );

  final doc = pw.Document(title: d.numero, author: entreprise['nom'] as String?, creator: 'DubaGest');
  doc.addPage(
    pw.Page(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        textDirection: arabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        buildForeground: !annule
            ? null
            : (context) => pw.Center(
                  child: pw.Transform.rotateBox(
                    angle: 0.5,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.red, width: 3),
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Text(l.docCancelledStamp,
                          style: pw.TextStyle(color: PdfColors.red, fontSize: 36, fontWeight: pw.FontWeight.bold)),
                    ),
                  ),
                ),
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // En-tête de l'entreprise (figé à l'émission) ; logo s'il existe.
          pw.Row(children: [
            if (logo != null) ...[
              pw.Image(pw.MemoryImage(logo), width: 44, height: 44, fit: pw.BoxFit.contain),
              pw.SizedBox(width: 10),
            ],
            pw.Expanded(
              child: pw.Text(entreprise['nom'] as String? ?? '',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: encre)),
            ),
          ]),
          if ([entreprise['adresse'], entreprise['ville']].whereType<String>().isNotEmpty)
            pw.Text([entreprise['adresse'], entreprise['ville']].whereType<String>().join(', '),
                style: const pw.TextStyle(fontSize: 9, color: gris)),
          if (entreprise['telephone'] case final String tel)
            pw.Text(l.docPhone(tel), style: const pw.TextStyle(fontSize: 9, color: gris)),
          if (entreprise['identifiant_fiscal'] case final String nif)
            pw.Text(l.docTaxId(nif), style: const pw.TextStyle(fontSize: 9, color: gris)),
          if (entreprise['registre_commerce'] case final String rc)
            pw.Text(l.docTradeRegister(rc), style: const pw.TextStyle(fontSize: 9, color: gris)),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            color: vert,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(l.docReceiptTitle,
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(d.numero, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          info(l.docDate, dateDoc),
          info(l.docReceivedFrom,
              contact == null ? null : [contact['nom'], contact['telephone']].whereType<String>().join(' · ')),
          info(l.docPaymentMode, l.modePaiement(ModePaiement.parse(paiement['mode'] as String?))),
          info(l.docReference, paiement['reference'] as String?),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: vert, width: 1.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(children: [
              pw.Text(l.docAmountReceived, style: const pw.TextStyle(color: gris, fontSize: 10)),
              pw.SizedBox(height: 4),
              pw.Text(montant(paiement['montant'] ?? d.montant),
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: encre)),
            ]),
          ),
          if (lignes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Text(l.docSettles, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: [l.docColumnLabel, l.docColumnAmount, l.docColumnRemaining],
              data: [
                for (final x in lignes) [x['libelle'] ?? '', montant(x['montant']), montant(x['reste'])],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE6F4EC)),
              cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight},
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE1E8E4)),
            ),
          ],
          pw.Spacer(),
          if (c['emis_par'] case final String auteur)
            pw.Text(l.docIssuedBy(auteur), style: const pw.TextStyle(fontSize: 9, color: gris)),
          pw.Divider(color: const PdfColor.fromInt(0xFFE1E8E4)),
          // Mention de l'entreprise (paramètres), figée à l'émission.
          if (c['pied'] case final String pied when pied.isNotEmpty) ...[
            pw.Text(pied, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 9, color: encre)),
            pw.SizedBox(height: 4),
          ],
          pw.Text(l.docGeneratedBy, style: const pw.TextStyle(fontSize: 8, color: gris)),
        ],
      ),
    ),
  );
  return doc.save();
}
