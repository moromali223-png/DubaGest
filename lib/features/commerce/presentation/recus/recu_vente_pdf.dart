import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../app/localization/l10n.dart';
import '../../../documents/presentation/pdf/recu_pdf.dart' show PolicesPdf;
import 'recu_vente.dart';

/// Charte DubaGest du reçu imprimé ; lisible aussi en noir et blanc
/// (le texte reste noir, la couleur n'est qu'un accent).
const _bleu = PdfColor.fromInt(0xFF01226C);
const _or = PdfColor.fromInt(0xFFDF9540);
const _encre = PdfColor.fromInt(0xFF172033);
const _gris = PdfColor.fromInt(0xFF64748B);
const _trait = PdfColor.fromInt(0xFFCBD5E1);

/// Reçu de vente en PDF. [format] : A5/A4 (partage, imprimante de bureau) ou
/// rouleau 58/80 mm (imprimante ticket) — la mise en page s'adapte.
Future<Uint8List> genererRecuVentePdf(
  DonneesRecu d, {
  required AppLocalizations l,
  required String langue,
  PdfPageFormat format = PdfPageFormat.a5,
  PolicesPdf? polices,
}) async {
  final p = polices ?? await PolicesPdf.charger();
  final arabe = langue == 'ar';
  final ticket = format.width < 100 * PdfPageFormat.mm;
  final t = ticket ? 0.85 : 1.0; // échelle des textes
  final nombres = NumberFormat.decimalPattern(langue);
  final unite = d.devise == 'XOF' ? 'FCFA' : d.devise;
  String m(int v) => '${nombres.format(v)} $unite';
  String n(int v) => nombres.format(v);

  pw.TextStyle st(double taille, {bool gras = false, PdfColor couleur = _encre}) =>
      pw.TextStyle(fontSize: taille * t, fontWeight: gras ? pw.FontWeight.bold : null, color: couleur);
  pw.Widget separateur() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Divider(color: _trait, thickness: 0.8, height: 1),
      );
  pw.Widget ligne(String gauche, String droite, {bool gras = false, double taille = 10, PdfColor couleur = _encre}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text(gauche, style: st(taille, gras: gras, couleur: couleur))),
          pw.Text(droite, style: st(taille, gras: gras, couleur: couleur)),
        ]),
      );
  pw.Widget info(String label, String? valeur) => valeur == null || valeur.isEmpty
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.SizedBox(width: ticket ? 52 : 70, child: pw.Text(label, style: st(9, couleur: _gris))),
            pw.Expanded(child: pw.Text(valeur, style: st(9.5, gras: true))),
          ]),
        );

  final date = DateFormat.yMd(langue).format(d.date);
  final heure = DateFormat.Hm(langue).format(d.date);

  List<pw.Widget> contenu() => [
        // En-tête : entreprise et boutique.
        if (d.logo != null)
          pw.Center(child: pw.Image(pw.MemoryImage(d.logo!), height: ticket ? 36 : 48, fit: pw.BoxFit.contain)),
        pw.SizedBox(height: 4),
        pw.Text(d.entreprise, textAlign: pw.TextAlign.center, style: st(15, gras: true, couleur: _bleu)),
        pw.SizedBox(height: 2),
        pw.Text('${l.rcpShop} : ${d.boutique}', textAlign: pw.TextAlign.center, style: st(9.5)),
        if (d.adresse case final a? when a.isNotEmpty)
          pw.Text(a, textAlign: pw.TextAlign.center, style: st(9, couleur: _gris)),
        if (d.telephone case final tel? when tel.isNotEmpty)
          pw.Text(l.docPhone(tel), textAlign: pw.TextAlign.center, style: st(9, couleur: _gris)),
        if (d.identifiantFiscal case final nif? when nif.isNotEmpty)
          pw.Text(l.docTaxId(nif), textAlign: pw.TextAlign.center, style: st(8.5, couleur: _gris)),
        if (d.registreCommerce case final rc? when rc.isNotEmpty)
          pw.Text(l.docTradeRegister(rc), textAlign: pw.TextAlign.center, style: st(8.5, couleur: _gris)),
        separateur(),

        // Titre et références.
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _bleu, width: 1.2), borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(children: [
            pw.Text(l.rcpSaleReceipt, style: st(12, gras: true, couleur: _bleu)),
            pw.SizedBox(height: 2),
            pw.Text(d.numero ?? l.rcpNumberPending, style: st(d.numero == null ? 8.5 : 11, gras: true)),
          ]),
        ),
        pw.SizedBox(height: 6),
        info(l.rcpDate, '$date · $heure'),
        info(l.comCustomer, d.client == null ? l.rcpCounterCustomer : [d.client, d.clientTelephone].whereType<String>().join(' · ')),
        info(l.comSeller, d.vendeur),
        separateur(),

        // Produits : unité réellement vendue, prix réellement appliqué.
        if (ticket)
          for (final x in d.lignes) ...[
            pw.Text(x.produit, style: st(9.5, gras: true)),
            ligne('${x.quantite} × ${n(x.prixUnitaire)}', n(x.montant), taille: 9),
            pw.SizedBox(height: 2),
          ]
        else
          pw.TableHelper.fromTextArray(
            headers: [l.rcpProduct, l.rcpQty, l.rcpPrice, l.rcpLineTotal],
            data: [for (final x in d.lignes) [x.produit, x.quantite, n(x.prixUnitaire), n(x.montant)]],
            headerStyle: st(8.5, gras: true, couleur: _bleu),
            cellStyle: st(9),
            headerDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _bleu, width: 0.8))),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
            columnWidths: {
              0: const pw.FlexColumnWidth(3.2),
              1: const pw.FlexColumnWidth(1.6),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.6),
            },
            cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            headerAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            border: null,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF7F9FC)),
          ),
        separateur(),

        // Montants : la remise n'apparaît que si elle existe.
        if (d.remise > 0) ...[
          ligne(l.rcpSubtotal, m(d.sousTotal)),
          ligne(l.comDiscount, '− ${m(d.remise)}'),
        ],
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 3),
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
          color: const PdfColor.fromInt(0xFFF7F9FC),
          child: ligne(l.comTotal.toUpperCase(), m(d.total), gras: true, taille: 13),
        ),
        pw.SizedBox(height: 4),
        info(l.comPayment, d.paiement),
        ligne(l.rcpPaid, m(d.paye), taille: 9.5),
        if (d.statut != StatutRecu.annule)
          d.reste > 0
              ? pw.Container(
                  margin: const pw.EdgeInsets.only(top: 4),
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: _or, width: 1.4)),
                  child: ligne(l.rcpRemainingToPay, m(d.reste), gras: true, taille: 11),
                )
              : ligne(l.rcpRemaining, m(0), taille: 9.5),
        if (d.annulation case final a?) ...[
          pw.SizedBox(height: 6),
          pw.Text(a, textAlign: pw.TextAlign.center, style: st(9, gras: true, couleur: PdfColors.red)),
        ],
        separateur(),

        // Pied.
        if (d.pied case final pied? when pied.isNotEmpty) ...[
          pw.Text(pied, textAlign: pw.TextAlign.center, style: st(9)),
          pw.SizedBox(height: 3),
        ],
        pw.Text(l.rcpThanks, textAlign: pw.TextAlign.center, style: st(10, gras: true)),
        pw.SizedBox(height: 6),
        pw.Text('DUBAGEST', textAlign: pw.TextAlign.center, style: st(8, gras: true, couleur: _bleu)),
        pw.Text(l.rcpTagline, textAlign: pw.TextAlign.center, style: st(7.5, couleur: _gris)),
      ];

  // Tampon « ANNULÉ » : le reçu reste consultable, son statut est évident.
  pw.Widget? tampon(pw.Context _) => d.statut != StatutRecu.annule
      ? null
      : pw.Center(
          child: pw.Transform.rotateBox(
            angle: 0.45,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.red, width: 3),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(l.rcpCancelledStamp,
                  style: pw.TextStyle(color: PdfColors.red, fontSize: ticket ? 22 : 34, fontWeight: pw.FontWeight.bold)),
            ),
          ),
        );

  final theme = pw.ThemeData.withFont(
    base: arabe ? p.arabe : p.latin,
    bold: arabe ? p.arabeGras : p.latinGras,
    fontFallback: arabe ? [p.latin, p.latinGras] : [p.arabe, p.arabeGras],
  );
  final pageTheme = pw.PageTheme(
    pageFormat: format,
    margin: pw.EdgeInsets.all(ticket ? 8 : 26),
    theme: theme,
    textDirection: arabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    buildForeground: d.statut == StatutRecu.annule ? (c) => tampon(c)! : null,
  );

  final doc = pw.Document(title: d.numero ?? l.rcpSaleReceipt, author: d.entreprise, creator: 'DubaGest');
  if (format.height == double.infinity) {
    // Rouleau : une seule page, aussi longue que le reçu.
    doc.addPage(pw.Page(
      pageTheme: pageTheme,
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: contenu()),
    ));
  } else {
    doc.addPage(pw.MultiPage(pageTheme: pageTheme, build: (_) => contenu()));
  }
  return doc.save();
}
