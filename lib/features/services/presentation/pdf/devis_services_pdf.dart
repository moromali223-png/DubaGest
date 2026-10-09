import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../contacts/domain/entities/contact.dart';
import '../../../documents/presentation/pdf/recu_pdf.dart' show PolicesPdf;
import '../../../entreprise/domain/entities/entreprise.dart';
import '../../domain/entities/prestation.dart';

/// Générateur PDF haute définition et professionnel pour les devis de services.
Future<Uint8List> genererDevisPdf(
  DevisPrestation devis, {
  Entreprise? entreprise,
  Contact? client,
  PolicesPdf? polices,
  Uint8List? logo,
}) async {
  final p = polices ?? await PolicesPdf.charger();
  final pdf = pw.Document();

  const bleuMarine = PdfColor.fromInt(0xFF01226C);
  const bleuClair = PdfColor.fromInt(0xFFF0F4FF);
  const grisBordure = PdfColor.fromInt(0xFFE2E8F0);
  const texteGris = PdfColor.fromInt(0xFF64748B);
  const texteEncre = PdfColor.fromInt(0xFF0F172A);

  final dateFormat = DateFormat('dd/MM/yyyy');
  final montantFormat = NumberFormat('#,##0', 'fr_FR');

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // 1. En-tête : Logo & Informations Entreprise + Badge DEVIS
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logo != null)
                      pw.Container(
                        width: 120,
                        height: 50,
                        margin: const pw.EdgeInsets.only(bottom: 8),
                        child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                      ),
                    pw.Text(
                      entreprise?.nom ?? 'DUBAGEST SERVICES',
                      style: pw.TextStyle(font: p.latinGras, fontSize: 18, color: bleuMarine),
                    ),
                    if (entreprise?.pays != null)
                      pw.Text(
                        'Pays : ${entreprise!.pays}',
                        style: pw.TextStyle(font: p.latin, fontSize: 10, color: texteGris),
                      ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(14),
                  decoration: pw.BoxDecoration(
                    color: bleuClair,
                    borderRadius: pw.BorderRadius.circular(10),
                    border: pw.Border.all(color: grisBordure),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DEVIS PROFORMA',
                        style: pw.TextStyle(font: p.latinGras, fontSize: 14, color: bleuMarine),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('N° ${devis.numero}', style: pw.TextStyle(font: p.latinGras, fontSize: 11, color: texteEncre)),
                      pw.SizedBox(height: 4),
                      pw.Text('Émis le : ${dateFormat.format(devis.dateEmission)}', style: pw.TextStyle(font: p.latin, fontSize: 9)),
                      if (devis.dateValidite != null)
                        pw.Text('Valide jusqu\'au : ${dateFormat.format(devis.dateValidite!)}',
                            style: pw.TextStyle(font: p.latinGras, fontSize: 9, color: const PdfColor.fromInt(0xFFC2410C))),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // 2. Coordonnées Client & Objet
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: grisBordure),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DESTINATAIRE / CLIENT :', style: pw.TextStyle(font: p.latinGras, fontSize: 9.5, color: texteGris)),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          client?.nomAffiche ?? 'Client particulier / Non enregistré',
                          style: pw.TextStyle(font: p.latinGras, fontSize: 12, color: texteEncre),
                        ),
                        if (client?.telephone != null)
                          pw.Text('Tél : ${client!.telephone}', style: pw.TextStyle(font: p.latin, fontSize: 9.5)),
                        if (client?.email != null)
                          pw.Text('Email : ${client!.email}', style: pw.TextStyle(font: p.latin, fontSize: 9.5)),
                        if (client?.adresse != null)
                          pw.Text('Adresse : ${client!.adresse}', style: pw.TextStyle(font: p.latin, fontSize: 9.5)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('OBJET DE LA DEMANDE :', style: pw.TextStyle(font: p.latinGras, fontSize: 9.5, color: texteGris)),
                        pw.SizedBox(height: 4),
                        pw.Text(devis.titre, style: pw.TextStyle(font: p.latinGras, fontSize: 11, color: texteEncre)),
                        if (devis.description != null && devis.description!.isNotEmpty)
                          pw.Text(devis.description!, style: pw.TextStyle(font: p.latin, fontSize: 9, color: texteGris)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),

            // 3. Tableau des prestations & chiffrage
            pw.TableHelper.fromTextArray(
              headers: ['Désignation / Prestation', 'Quantité', 'Prix Unitaire (FCFA)', 'Total Ligne (FCFA)'],
              data: devis.lignes.map((l) {
                return [
                  l.libelle,
                  l.quantite.toString(),
                  montantFormat.format(l.prixUnitaire),
                  montantFormat.format(l.totalLigne),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: p.latinGras, fontSize: 9.5, color: bleuMarine),
              headerDecoration: const pw.BoxDecoration(color: bleuClair),
              cellStyle: pw.TextStyle(font: p.latin, fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: grisBordure, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              headerPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            pw.SizedBox(height: 12),

            // 4. Totaux & Conditions
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 6,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (devis.conditions != null && devis.conditions!.isNotEmpty) ...[
                        pw.Text('CONDITIONS & MODALITÉS :', style: pw.TextStyle(font: p.latinGras, fontSize: 9, color: texteGris)),
                        pw.SizedBox(height: 2),
                        pw.Text(devis.conditions!, style: pw.TextStyle(font: p.latin, fontSize: 8.5, color: texteEncre)),
                        pw.SizedBox(height: 10),
                      ],
                      pw.Text(
                        'Pour accepter ce devis, veuillez retourner un exemplaire signé précédé de la mention manuscrite « Bon pour accord ».',
                        style: pw.TextStyle(font: p.latin, fontSize: 8, fontStyle: pw.FontStyle.italic, color: texteGris),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  flex: 4,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: bleuClair,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: grisBordure),
                    ),
                    child: pw.Column(
                      children: [
                        if (devis.remise > 0) ...[
                          _ligneTotal('Sous-total brut', '${montantFormat.format(devis.lignes.fold<int>(0, (s, l) => s + l.totalLigne))} FCFA', p),
                          _ligneTotal('Remise commerciale', '- ${montantFormat.format(devis.remise)} FCFA', p),
                          pw.Divider(color: grisBordure),
                        ],
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL NET :', style: pw.TextStyle(font: p.latinGras, fontSize: 11, color: bleuMarine)),
                            pw.Text('${montantFormat.format(devis.total)} FCFA',
                                style: pw.TextStyle(font: p.latinGras, fontSize: 13, color: bleuMarine)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.Spacer(),

            // 5. Cadres de Signature
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Pour l\'entreprise (Cachet & Signature) :', style: pw.TextStyle(font: p.latinGras, fontSize: 9)),
                    pw.Container(
                      width: 160,
                      height: 50,
                      margin: const pw.EdgeInsets.only(top: 4),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: grisBordure)),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bon pour accord (Signature Client) :', style: pw.TextStyle(font: p.latinGras, fontSize: 9)),
                    pw.Container(
                      width: 160,
                      height: 50,
                      margin: const pw.EdgeInsets.only(top: 4),
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: grisBordure)),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Center(
              child: pw.Text(
                'Document généré par DUBAGEST — Système professionnel de gestion d\'entreprise',
                style: pw.TextStyle(font: p.latin, fontSize: 7.5, color: texteGris),
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _ligneTotal(String label, String valeur, PolicesPdf p) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: p.latin, fontSize: 9)),
        pw.Text(valeur, style: pw.TextStyle(font: p.latinGras, fontSize: 9.5)),
      ],
    ),
  );
}
