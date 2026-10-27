import 'dart:typed_data';

import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../app/localization/l10n.dart';
import '../../domain/entities/document.dart';
import 'recu_pdf.dart' show PolicesPdf;

/// Générateur PDF haute définition et adaptatif pour tous les documents DUBAGEST.
/// Gère : REÇU, FACTURE, DEVIS, AVOIR, BON_COMMANDE, BON_TRAVAIL, QUITTANCE, CONTRAT.
Future<Uint8List> genererDocumentPdf(
  Document d, {
  bool annule = false,
  PolicesPdf? polices,
  Uint8List? logo,
}) async {
  final p = polices ?? await PolicesPdf.charger();
  final codeLangue = switch (d.langue.toLowerCase()) {
    'ar' => 'ar',
    'en' => 'en',
    _ => 'fr',
  };
  await initializeDateFormatting(codeLangue);
  final l = lookupAppLocalizations(Locale(codeLangue));
  final arabe = codeLangue == 'ar';

  final c = d.contenu;
  final entreprise = (c['entreprise'] as Map?)?.cast<String, dynamic>() ?? const {};
  final contact = (c['contact'] as Map?)?.cast<String, dynamic>();
  final lignes = ((c['lignes'] as List?) ?? const []).cast<Map>();
  final devise = entreprise['devise'] as String? ?? 'XOF';
  final uniteDevise = devise == 'XOF' ? 'FCFA' : devise;

  final nombres = NumberFormat('#,##0', 'fr');
  String formatMonnaie(Object? v) {
    final num? val = v is num ? v : (v != null ? num.tryParse(v.toString()) : null);
    return '${nombres.format(val ?? 0)} $uniteDevise';
  }
  final dateDoc = DateFormat('dd/MM/yyyy').format(d.date.toLocal());

  // Couleurs professionnelles DubaGest (Vert Émeraude #1E7E4E & Ardoise #1A2522)
  const vert = PdfColor.fromInt(0xFF1E7E4E);
  const vertClair = PdfColor.fromInt(0xFFE8F5EE);
  const ardoise = PdfColor.fromInt(0xFF1A2522);
  const orAccent = PdfColor.fromInt(0xFFD97706);
  const encre = PdfColor.fromInt(0xFF1A2522);
  const texteGris = PdfColor.fromInt(0xFF64748B);
  const grisBordure = PdfColor.fromInt(0xFFCBD5E1);

  final theme = pw.ThemeData.withFont(
    base: arabe ? p.arabe : p.latin,
    bold: arabe ? p.arabeGras : p.latinGras,
    fontFallback: arabe ? [p.latin, p.latinGras] : [p.arabe, p.arabeGras],
  );

  // Libellé et couleur de badge selon le type
  final (String typeTitre, PdfColor couleurTheme, PdfColor couleurFond) = switch (d.type) {
    TypeDocument.facture => (l.docTypeInvoice.toUpperCase(), vert, vertClair),
    TypeDocument.devis => ('${l.docTypeQuote.toUpperCase()} PROFORMA', orAccent, const PdfColor.fromInt(0xFFFFF7ED)),
    TypeDocument.recu => (l.docReceiptTitle, vert, vertClair),
    TypeDocument.avoir => (l.docTypeCreditNote.toUpperCase(), const PdfColor.fromInt(0xFFB91C1C), const PdfColor.fromInt(0xFFFEE2E2)),
    TypeDocument.bonCommande => ('BON DE COMMANDE', vert, vertClair),
    TypeDocument.bonTravail => ('ORDRE DE TRAVAIL / INTERVENTION', ardoise, vertClair),
    TypeDocument.quittance => ('QUITTANCE DE LOYER', vert, vertClair),
    TypeDocument.contrat => ('CONTRAT', ardoise, vertClair),
  };

  // Tampon
  final estPaye = (c['statut'] == 'PAYE' || c['reste'] == 0) &&
      d.type != TypeDocument.devis &&
      d.type != TypeDocument.bonCommande;

  pw.Widget? construireTampon() {
    if (annule || d.refuse) {
      return pw.Center(
        child: pw.Transform.rotateBox(
          angle: 0.45,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.red, width: 3.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(l.docCancelledStamp,
                style: pw.TextStyle(color: PdfColors.red, fontSize: 36, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      );
    }
    if (d.type == TypeDocument.devis) {
      return pw.Center(
        child: pw.Transform.rotateBox(
          angle: 0.45,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: orAccent, width: 2.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('PROFORMA',
                style: pw.TextStyle(color: orAccent, fontSize: 32, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      );
    }
    if (estPaye && (d.type == TypeDocument.facture || d.type == TypeDocument.quittance)) {
      return pw.Center(
        child: pw.Transform.rotateBox(
          angle: -0.35,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: vert, width: 2.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text('ACQUITTÉ / RÉGLÉ',
                style: pw.TextStyle(color: vert, fontSize: 30, fontWeight: pw.FontWeight.bold)),
          ),
        ),
      );
    }
    return null;
  }

  final tamponWidget = construireTampon();
  final doc = pw.Document(title: d.numero, author: entreprise['nom'] as String?, creator: 'DubaGest');

  doc.addPage(
    pw.MultiPage(
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: theme,
        textDirection: arabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        buildForeground: tamponWidget != null ? (_) => tamponWidget : null,
      ),
      build: (ctx) => [
        // 1. En-tête : Logo & Entreprise + Badge Numéro
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logo != null && logo.isNotEmpty)
                    pw.Container(
                      width: 120,
                      height: 48,
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                    ),
                  pw.Text(
                    entreprise['nom'] as String? ?? 'DUBAGEST',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: ardoise),
                  ),
                  if ([entreprise['adresse'], entreprise['ville']].whereType<String>().isNotEmpty)
                    pw.Text([entreprise['adresse'], entreprise['ville']].whereType<String>().join(', '),
                        style: const pw.TextStyle(fontSize: 9, color: texteGris)),
                  if (entreprise['telephone'] case final String tel)
                    pw.Text(l.docPhone(tel), style: const pw.TextStyle(fontSize: 9, color: texteGris)),
                  if (entreprise['identifiant_fiscal'] case final String nif)
                    pw.Text(l.docTaxId(nif), style: const pw.TextStyle(fontSize: 8.5, color: texteGris)),
                  if (entreprise['registre_commerce'] case final String rc)
                    pw.Text(l.docTradeRegister(rc), style: const pw.TextStyle(fontSize: 8.5, color: texteGris)),
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 5,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: couleurFond,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: couleurTheme, width: 1.2),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(typeTitre,
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: couleurTheme)),
                    pw.SizedBox(height: 4),
                    pw.Text('N° ${d.numero}',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: encre)),
                    pw.SizedBox(height: 4),
                    pw.Text('${l.docDate} : $dateDoc', style: const pw.TextStyle(fontSize: 9, color: texteGris)),
                    if (c['date_echeance'] case final String ech)
                      pw.Text(
                        d.type == TypeDocument.bonCommande
                            ? 'Livraison souhaitée : ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(ech)?.toLocal() ?? DateTime.now())}'
                            : 'Échéance : ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(ech)?.toLocal() ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orAccent),
                      ),
                    if (c['date_validite'] case final String val)
                      pw.Text(
                        'Valide jusqu\'au : ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(val)?.toLocal() ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orAccent),
                      ),
                    if (c['date_livraison'] case final String liv)
                      pw.Text(
                        'Livraison prévue : ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(liv)?.toLocal() ?? DateTime.now())}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orAccent),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 18),

        // 2. Destinataire & Objet
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: grisBordure, width: 0.8),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 5,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      d.type == TypeDocument.bonCommande
                          ? (c['type_bc'] == 'CLIENT' ? 'CLIENT / DONNEUR D\'ORDRE :' : 'FOURNISSEUR / PRESTATAIRE :')
                          : 'DESTINATAIRE / CLIENT :',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: texteGris),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      contact?['nom'] as String? ?? 'Client / Partenaire',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: encre),
                    ),
                    if (contact?['telephone'] case final String tel)
                      pw.Text('Tél : $tel', style: const pw.TextStyle(fontSize: 9)),
                    if (contact?['email'] case final String email)
                      pw.Text('Email : $email', style: const pw.TextStyle(fontSize: 9)),
                    if (contact?['adresse'] case final String adr)
                      pw.Text('Adresse : $adr', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              if (c['titre'] != null || c['description'] != null || c['reference_metier'] != null) ...[
                pw.SizedBox(width: 12),
                pw.Expanded(
                  flex: 5,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('OBJET / RÉFÉRENCE :',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: texteGris)),
                      pw.SizedBox(height: 3),
                      if (c['titre'] case final String t)
                        pw.Text(t, style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: encre)),
                      if (c['reference_metier'] case final String ref)
                        pw.Text('Réf : $ref', style: const pw.TextStyle(fontSize: 9, color: texteGris)),
                      if (c['description'] case final String desc)
                        pw.Text(desc, style: const pw.TextStyle(fontSize: 8.5, color: texteGris)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 14),

        // 3. Tableau des Lignes
        if (lignes.isNotEmpty) ...[
          pw.TableHelper.fromTextArray(
            headers: [
              l.docColumnLabel,
              l.rcpQty,
              l.rcpPrice,
              l.rcpLineTotal,
            ],
            data: [
              for (final x in lignes)
                [
                  x['libelle'] ?? x['designation'] ?? x['produit'] ?? '',
                  (x['quantite'] ?? '1').toString(),
                  formatMonnaie(x['prix_unitaire'] ?? x['prix'] ?? 0),
                  formatMonnaie(x['montant'] ?? x['total_ligne'] ?? 0),
                ]
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: couleurTheme),
            headerDecoration: pw.BoxDecoration(color: couleurFond),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            border: pw.TableBorder.all(color: grisBordure, width: 0.5),
          ),
          pw.SizedBox(height: 12),
        ],

        // 4. Totaux & Règlements
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (c['conditions'] case final String cond when cond.isNotEmpty) ...[
                    pw.Text('CONDITIONS & MODALITÉS :',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: texteGris)),
                    pw.SizedBox(height: 2),
                    pw.Text(cond, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 6),
                  ],
                  if (c['notes'] case final String notes when notes.isNotEmpty) ...[
                    pw.Text('NOTES :',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: texteGris)),
                    pw.SizedBox(height: 2),
                    pw.Text(notes, style: const pw.TextStyle(fontSize: 8)),
                  ],
                ],
              ),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 5,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: couleurFond,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: grisBordure),
                ),
                child: pw.Column(
                  children: [
                    if (c['sous_total'] case final num st when st != d.montant) ...[
                      _ligneTotal('Sous-total brut', formatMonnaie(st)),
                      if (c['remise'] case final num rem when rem > 0)
                        _ligneTotal('Remise commerciale', '- ${formatMonnaie(rem)}'),
                      pw.Divider(color: grisBordure, height: 6),
                    ],
                    _ligneTotal(
                      'TOTAL :',
                      formatMonnaie(d.montant),
                      gras: true,
                      taille: 11,
                      couleur: couleurTheme,
                    ),
                    if (c['paye'] case final num paye) ...[
                      pw.SizedBox(height: 4),
                      _ligneTotal('Montant réglé', formatMonnaie(paye)),
                    ],
                    if (c['reste'] case final num reste when reste > 0) ...[
                      pw.SizedBox(height: 4),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                            color: d.type == TypeDocument.bonCommande
                                ? const PdfColor.fromInt(0xFFEA580C)
                                : (d.type == TypeDocument.avoir ? const PdfColor.fromInt(0xFFDC2626) : vert),
                            width: 1.2,
                          ),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: _ligneTotal(
                          d.type == TypeDocument.bonCommande
                              ? 'Reste à payer'
                              : (d.type == TypeDocument.avoir ? 'Avoir restant' : 'Reste à recevoir'),
                          formatMonnaie(reste),
                          gras: true,
                          couleur: d.type == TypeDocument.bonCommande
                              ? const PdfColor.fromInt(0xFFEA580C)
                              : (d.type == TypeDocument.avoir ? const PdfColor.fromInt(0xFFDC2626) : vert),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 20),

        // 5. Cadres de Signature & Cachet
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  d.type == TypeDocument.bonCommande
                      ? 'Pour le Commanditaire (Visa & Cachet) :'
                      : 'Pour l\'entreprise (Cachet & Signature) :',
                  style: const pw.TextStyle(fontSize: 8.5, color: texteGris),
                ),
                pw.Container(
                  width: 160,
                  height: 44,
                  margin: const pw.EdgeInsets.only(top: 4),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: grisBordure)),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  d.type == TypeDocument.devis
                      ? 'Bon pour accord (Signature Client) :'
                      : d.type == TypeDocument.bonCommande
                          ? 'Pour le Fournisseur (Accord & Date) :'
                          : 'Pour réception / Accord :',
                  style: const pw.TextStyle(fontSize: 8.5, color: texteGris),
                ),
                pw.Container(
                  width: 160,
                  height: 44,
                  margin: const pw.EdgeInsets.only(top: 4),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: grisBordure)),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // 6. Pied de page
        if (c['pied'] case final String pied when pied.isNotEmpty) ...[
          pw.Center(
            child: pw.Text(pied, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8.5)),
          ),
          pw.SizedBox(height: 4),
        ],
        pw.Center(
          child: pw.Text(l.docGeneratedBy,
              style: const pw.TextStyle(fontSize: 7.5, color: texteGris)),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _ligneTotal(String label, String valeur, {bool gras = false, double taille = 9, PdfColor? couleur}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: taille, fontWeight: gras ? pw.FontWeight.bold : null)),
        pw.Text(valeur,
            style: pw.TextStyle(
              fontSize: taille,
              fontWeight: gras ? pw.FontWeight.bold : null,
              color: couleur,
            )),
      ],
    ),
  );
}
