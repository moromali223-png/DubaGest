import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../documents/presentation/pdf/recu_pdf.dart';
import '../../../entreprise/domain/entities/entreprise.dart';
import '../../../immobilier/domain/services/montant_en_lettres.dart';
import '../../domain/entities/microfinance_enums.dart';
import '../../domain/entities/microfinance_models.dart';
import '../../domain/services/delinquency_analyzer.dart';

/// Générateur de documents officiels PDF du module Microfinance :
/// 1. Contrat de prêt
/// 2. Reçu de décaissement
/// 3. Reçu de remboursement
/// 4. Échéancier imprimable
/// 5. Situation financière individuelle de l'emprunteur
/// 6. Rapport financier périodique Microfinance
abstract final class MicrofinancePdfGenerator {
  static const _vert = PdfColor.fromInt(0xFF1E7E4E);
  static const _vertDoux = PdfColor.fromInt(0xFFE8F5EE);
  static const _encre = PdfColor.fromInt(0xFF1A2522);
  static const _gris = PdfColor.fromInt(0xFF56675F);
  static const _bordure = PdfColor.fromInt(0xFFE2E8F0);
  static const _rouge = PdfColor.fromInt(0xFFDC2626);

  static String _fmtMontant(int v, String devise) {
    final u = devise == 'XOF' ? 'FCFA' : devise;
    return '${NumberFormat.decimalPattern('fr').format(v)} $u';
  }

  static String _fmtDate(DateTime d) => DateFormat('dd/MM/yyyy').format(d.toLocal());
  static String _fmtDateHeure(DateTime d) => DateFormat('dd/MM/yyyy à HH:mm').format(d.toLocal());

  static Future<pw.ThemeData> _theme({bool arabe = false}) async {
    final p = await PolicesPdf.charger();
    return pw.ThemeData.withFont(
      base: arabe ? p.arabe : p.latin,
      bold: arabe ? p.arabeGras : p.latinGras,
      fontFallback: arabe ? [p.latin, p.latinGras] : [p.arabe, p.arabeGras],
    );
  }

  static pw.Widget _enTete({
    required Entreprise? entreprise,
    required String titreDocument,
    required String reference,
    required String dateStr,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _vert, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entreprise?.nom.toUpperCase() ?? 'DUBAGEST MICROFINANCE',
                  style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _encre),
                ),
                pw.Text(
                  'DubaGest Microfinance${(entreprise?.pays != null && entreprise!.pays!.isNotEmpty) ? ' • ${entreprise.pays}' : ''}',
                  style: const pw.TextStyle(fontSize: 9, color: _gris),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: _vertDoux,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  titreDocument,
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _vert),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Réf : $reference',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
              pw.Text('Émis le : $dateStr', style: const pw.TextStyle(fontSize: 8.5, color: _gris)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _blocInfo(String label, String? value) {
    if (value == null || value.trim().isEmpty) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _gris)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _encre)),
          ),
        ],
      ),
    );
  }

  /// 1. Contrat de prêt officiel.
  static Future<Uint8List> genererContratPretPdf({
    required Entreprise? entreprise,
    required MicrofinanceBorrower borrower,
    required MicrofinanceLoan loan,
    required List<MicrofinanceInstallment> installments,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final doc = pw.Document(title: 'Contrat ${loan.reference}', creator: 'DubaGest Microfinance');

    final triees = List<MicrofinanceInstallment>.from(installments)
      ..sort((a, b) => a.numeroEcheance.compareTo(b.numeroEcheance));

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          theme: theme,
        ),
        build: (_) => [
          _enTete(
            entreprise: entreprise,
            titreDocument: 'CONTRAT DE PRÊT',
            reference: loan.reference,
            dateStr: _fmtDate(loan.dateOctroi),
          ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _bordure),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PARTIES CONTRACTANTES',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _vert)),
                pw.SizedBox(height: 6),
                _blocInfo('Prêteur :', entreprise?.nom ?? 'DubaGest Microfinance'),
                _blocInfo('Emprunteur :', '${borrower.nomComplet} (${borrower.codeEmprunteur})'),
                _blocInfo('Téléphone :', borrower.telephone),
                _blocInfo('Adresse / Localisation :', borrower.localisation ?? borrower.adresse),
                _blocInfo('Profession / Activité :',
                    [borrower.profession, borrower.activite].where((e) => e != null && e.isNotEmpty).join(' — ')),
                if (borrower.referencePiece != null && borrower.referencePiece!.isNotEmpty)
                  _blocInfo('Pièce d\'identité :',
                      '${borrower.typePiece ?? "Pièce"} n° ${borrower.referencePiece}'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _vertDoux,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CONDITIONS FINANCIÈRES DU PRÊT',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _vert)),
                pw.SizedBox(height: 6),
                _blocInfo('Capital emprunté :', _fmtMontant(loan.montantAccorde, devise)),
                _blocInfo('Arrêté en lettres :',
                    MontantEnLettres.convertir(loan.montantAccorde, devise: devise)),
                _blocInfo('Méthode d\'intérêt :',
                    '${loan.methodeInteret.libelle("fr")} (${loan.methodeInteret == MethodeCalculInteret.montantFixe ? _fmtMontant(loan.montantInteretFixe, devise) : "${loan.tauxInteret}%"})'),
                _blocInfo('Coût total intérêts :', _fmtMontant(loan.montantInteretTotal, devise)),
                _blocInfo('Total à rembourser :', _fmtMontant(loan.montantTotalARembourser, devise)),
                _blocInfo('Fréquence & durée :',
                    '${loan.nombreEcheances} échéance(s) (${loan.frequence.libelle("fr")})'),
                _blocInfo('Première échéance :', _fmtDate(loan.dateDebut)),
                _blocInfo('Fin prévue :', _fmtDate(loan.dateFinPrevue)),
                if (loan.conditionsParticulieres != null && loan.conditionsParticulieres!.isNotEmpty)
                  _blocInfo('Conditions particulières :', loan.conditionsParticulieres),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Text('ÉCHÉANCIER CONTRACTUEL DE REMBOURSEMENT',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _encre),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: _encre),
            cellAlignment: pw.Alignment.centerRight,
            headers: ['N°', 'Date prévue', 'Capital', 'Intérêts', 'Total attendu'],
            data: [
              for (final e in triees)
                [
                  '${e.numeroEcheance}',
                  _fmtDate(e.datePrevue),
                  _fmtMontant(e.capitalPrevu, devise),
                  _fmtMontant(e.interetPrevu, devise),
                  _fmtMontant(e.montantTotalAttendu, devise),
                ],
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(children: [
                pw.Text('Signature du Prêteur',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 36),
                pw.Container(width: 150, height: 0.8, color: _gris),
              ]),
              pw.Column(children: [
                pw.Text('Signature de l\'Emprunteur (Lu et approuvé)',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 36),
                pw.Container(width: 180, height: 0.8, color: _gris),
              ]),
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// 2. Reçu de décaissement.
  static Future<Uint8List> genererRecuDecaissementPdf({
    required Entreprise? entreprise,
    required MicrofinanceBorrower borrower,
    required MicrofinanceLoan loan,
    required MicrofinanceAccount account,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final doc = pw.Document(title: 'Décaissement ${loan.reference}', creator: 'DubaGest');

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _enTete(
              entreprise: entreprise,
              titreDocument: 'REÇU DE DÉCAISSEMENT',
              reference: loan.reference,
              dateStr: _fmtDateHeure(loan.dateDecaissement ?? loan.dateOctroi),
            ),
            pw.SizedBox(height: 14),
            _blocInfo('Bénéficiaire :', '${borrower.nomComplet} (${borrower.telephone})'),
            _blocInfo('Compte source :', account.nom),
            _blocInfo('Moyen de décaissement :', loan.modeDecaissement.libelle('fr')),
            _blocInfo('Montant décaissé :', _fmtMontant(loan.montantAccorde, devise)),
            _blocInfo('En toutes lettres :',
                MontantEnLettres.convertir(loan.montantAccorde, devise: devise)),
            _blocInfo('Total à rembourser :', _fmtMontant(loan.montantTotalARembourser, devise)),
            _blocInfo('Nombre d\'échéances :',
                '${loan.nombreEcheances} (${loan.frequence.libelle("fr")})'),
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Signature Caissier', style: const pw.TextStyle(fontSize: 9, color: _gris)),
                pw.Text('Signature Emprunteur', style: const pw.TextStyle(fontSize: 9, color: _gris)),
              ],
            ),
            pw.SizedBox(height: 28),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// 3. Reçu officiel de remboursement (avec ventilation Capital / Intérêts et tampon ANNULÉ si applicable).
  static Future<Uint8List> genererRecuRemboursementPdf({
    required Entreprise? entreprise,
    required MicrofinanceBorrower borrower,
    required MicrofinanceLoan loan,
    required MicrofinanceRepayment repayment,
    required MicrofinanceAccount account,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final doc = pw.Document(title: 'Reçu ${repayment.reference}', creator: 'DubaGest');

    doc.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a5,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
          buildForeground: !repayment.estAnnule
              ? null
              : (_) => pw.Center(
                    child: pw.Transform.rotateBox(
                      angle: 0.45,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: _rouge, width: 3),
                          borderRadius: pw.BorderRadius.circular(6),
                        ),
                        child: pw.Text(
                          'ANNULÉ',
                          style: pw.TextStyle(
                              fontSize: 28, fontWeight: pw.FontWeight.bold, color: _rouge),
                        ),
                      ),
                    ),
                  ),
        ),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _enTete(
              entreprise: entreprise,
              titreDocument: 'REÇU DE REMBOURSEMENT',
              reference: repayment.reference,
              dateStr: _fmtDateHeure(repayment.datePaiement),
            ),
            pw.SizedBox(height: 12),
            _blocInfo('Emprunteur :', '${borrower.nomComplet} (${borrower.codeEmprunteur})'),
            _blocInfo('Téléphone :', borrower.telephone),
            _blocInfo('Prêt concerné :', loan.reference),
            _blocInfo('Type :', repayment.typeRemboursement.libelle('fr')),
            _blocInfo('Moyen & Compte :', '${repayment.modePaiement.libelle("fr")} — ${account.nom}'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _vertDoux,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _blocInfo('Montant total encaissé :', _fmtMontant(repayment.montantEncaisse, devise)),
                  _blocInfo('Arrêté à la somme de :',
                      MontantEnLettres.convertir(repayment.montantEncaisse, devise: devise)),
                  _blocInfo('Dont capital remboursé :', _fmtMontant(repayment.partCapital, devise)),
                  _blocInfo('Dont intérêts encaissés :', _fmtMontant(repayment.partInteret, devise)),
                  _blocInfo('Reste à payer du prêt :', _fmtMontant(loan.resteAPayerTotal, devise)),
                ],
              ),
            ),
            if (repayment.detailsAffectation.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'Échéances affectées : ${repayment.detailsAffectation.map((a) => '#${a.numeroEcheance} (${_fmtMontant(a.montantAffecte, devise)})').join(', ')}',
                style: const pw.TextStyle(fontSize: 8.5, color: _gris),
              ),
            ],
            if (repayment.observations != null && repayment.observations!.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text('Observations : ${repayment.observations}',
                  style: const pw.TextStyle(fontSize: 8.5, color: _encre)),
            ],
            pw.Spacer(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Signature Caissier', style: const pw.TextStyle(fontSize: 9, color: _gris)),
                pw.Text('Signature Emprunteur', style: const pw.TextStyle(fontSize: 9, color: _gris)),
              ],
            ),
            pw.SizedBox(height: 22),
          ],
        ),
      ),
    );
    return doc.save();
  }

  /// 4. Échéancier imprimable complet d'un prêt.
  static Future<Uint8List> genererEcheancierPdf({
    required Entreprise? entreprise,
    required MicrofinanceBorrower borrower,
    required MicrofinanceLoan loan,
    required List<MicrofinanceInstallment> installments,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final now = DateTime.now();
    final doc = pw.Document(title: 'Échéancier ${loan.reference}', creator: 'DubaGest');
    final triees = List<MicrofinanceInstallment>.from(installments)
      ..sort((a, b) => a.numeroEcheance.compareTo(b.numeroEcheance));

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
        ),
        build: (_) => [
          _enTete(
            entreprise: entreprise,
            titreDocument: 'ÉCHÉANCIER DE PRÊT',
            reference: loan.reference,
            dateStr: _fmtDate(now),
          ),
          pw.SizedBox(height: 10),
          _blocInfo('Emprunteur :', '${borrower.nomComplet} — ${borrower.telephone}'),
          _blocInfo('Montant accordé :', _fmtMontant(loan.montantAccorde, devise)),
          _blocInfo('Total à rembourser :', _fmtMontant(loan.montantTotalARembourser, devise)),
          _blocInfo('Déjà payé :', _fmtMontant(loan.totalRembourse, devise)),
          _blocInfo('Reste à payer :', _fmtMontant(loan.resteAPayerTotal, devise)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _vert),
            cellStyle: const pw.TextStyle(fontSize: 8.5, color: _encre),
            headers: ['#', 'Date prévue', 'Attendu', 'Déjà payé', 'Reste', 'Statut'],
            data: [
              for (final e in triees)
                [
                  '${e.numeroEcheance}',
                  _fmtDate(e.datePrevue),
                  _fmtMontant(e.montantTotalAttendu, devise),
                  _fmtMontant(e.montantDejaPaye, devise),
                  _fmtMontant(e.resteAPayer, devise),
                  DelinquencyAnalyzer.statutEcheanceActuel(e, now).libelle('fr'),
                ],
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// 5. Situation financière individuelle de l'emprunteur.
  static Future<Uint8List> genererSituationEmprunteurPdf({
    required Entreprise? entreprise,
    required MicrofinanceBorrowerSummary summary,
    required List<MicrofinanceLoan> loans,
    required List<MicrofinanceRepayment> repayments,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final now = DateTime.now();
    final doc = pw.Document(
      title: 'Situation ${summary.borrower.nomComplet}',
      creator: 'DubaGest',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
        ),
        build: (_) => [
          _enTete(
            entreprise: entreprise,
            titreDocument: 'SITUATION EMPRUNTEUR',
            reference: summary.borrower.codeEmprunteur,
            dateStr: _fmtDate(now),
          ),
          pw.SizedBox(height: 10),
          _blocInfo('Nom complet :', summary.borrower.nomComplet),
          _blocInfo('Téléphone :', summary.borrower.telephone),
          _blocInfo('Nombre de prêts :', '${summary.nombrePretsTotal} (dont ${summary.nombrePretsActifs} actifs)'),
          _blocInfo('Total emprunté :', _fmtMontant(summary.totalEmprunte, devise)),
          _blocInfo('Total remboursé :', _fmtMontant(summary.totalRembourse, devise)),
          _blocInfo('Reste à payer total :', _fmtMontant(summary.resteAPayerTotal, devise)),
          _blocInfo('Impayés en retard :', _fmtMontant(summary.montantImpayes, devise)),
          pw.SizedBox(height: 12),
          pw.Text('HISTORIQUE DES PRÊTS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _encre),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: ['Référence', 'Octroi', 'Capital', 'Total dû', 'Payé', 'Reste', 'Statut'],
            data: [
              for (final l in loans)
                [
                  l.reference,
                  _fmtDate(l.dateOctroi),
                  _fmtMontant(l.montantAccorde, devise),
                  _fmtMontant(l.montantTotalARembourser, devise),
                  _fmtMontant(l.totalRembourse, devise),
                  _fmtMontant(l.resteAPayerTotal, devise),
                  l.statut.libelle('fr'),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('DERNIERS REMBOURSEMENTS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 4),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _vert),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            headers: ['Référence', 'Date', 'Montant', 'Capital', 'Intérêts', 'Statut'],
            data: [
              for (final r in repayments)
                [
                  r.reference,
                  _fmtDate(r.datePaiement),
                  _fmtMontant(r.montantEncaisse, devise),
                  _fmtMontant(r.partCapital, devise),
                  _fmtMontant(r.partInteret, devise),
                  r.estAnnule ? 'Annulé' : 'Validé',
                ],
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// 6. Rapport financier global / périodique Microfinance.
  static Future<Uint8List> genererRapportGlobalPdf({
    required Entreprise? entreprise,
    required MicrofinanceDashboardStats stats,
    required String libellePeriode,
    required List<MicrofinanceLoan> loans,
    required Map<String, MicrofinanceBorrower> borrowersById,
  }) async {
    final theme = await _theme();
    final devise = entreprise?.devise ?? 'XOF';
    final now = DateTime.now();
    final doc = pw.Document(title: 'Rapport Microfinance', creator: 'DubaGest');

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          theme: theme,
        ),
        build: (_) => [
          _enTete(
            entreprise: entreprise,
            titreDocument: 'RAPPORT MICROFINANCE',
            reference: libellePeriode,
            dateStr: _fmtDateHeure(now),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _vertDoux,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('SYNTHÈSE FINANCIÈRE (SÉPARATION CAPITAL / CRÉANCES / RÉSULTAT)',
                    style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: _vert)),
                pw.SizedBox(height: 6),
                _blocInfo('Capital initial :', _fmtMontant(stats.capitalInitial, devise)),
                _blocInfo('Apports supplémentaires :', _fmtMontant(stats.apportsSupplementaires, devise)),
                _blocInfo('Capital disponible (Trésorerie) :',
                    _fmtMontant(stats.capitalTotalDisponible, devise)),
                _blocInfo('Montants décaissés :', _fmtMontant(stats.totalMontantsDecaisses, devise)),
                _blocInfo('Créances capital à récupérer :',
                    _fmtMontant(stats.capitalRestantARecuperer, devise)),
                _blocInfo('Intérêts prévus :', _fmtMontant(stats.totalInteretsPrevus, devise)),
                _blocInfo('Revenus réels (Intérêts encaissés) :',
                    _fmtMontant(stats.totalInteretsEncaisses, devise)),
                _blocInfo('Total remboursements reçus :',
                    _fmtMontant(stats.totalRemboursementsRecus, devise)),
                _blocInfo('Dépenses de fonctionnement :', _fmtMontant(stats.depensesFonctionnement, devise)),
                _blocInfo('Résultat financier net :', _fmtMontant(stats.resultatFinancierNet, devise)),
                _blocInfo('Impayés échus :',
                    '${_fmtMontant(stats.montantTotalImpayes, devise)} (${stats.nombrePretsEnRetard} prêts en retard)'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text('PORTEFEUILLE DES PRÊTS (${loans.length})',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _encre)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: _encre),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headers: ['Réf', 'Emprunteur', 'Capital', 'Intérêts', 'Remboursé', 'Reste', 'Statut'],
            data: [
              for (final l in loans.take(100))
                [
                  l.reference,
                  borrowersById[l.borrowerId]?.nomComplet ?? '-',
                  _fmtMontant(l.montantAccorde, devise),
                  _fmtMontant(l.montantInteretTotal, devise),
                  _fmtMontant(l.totalRembourse, devise),
                  _fmtMontant(l.resteAPayerTotal, devise),
                  l.statut.libelle('fr'),
                ],
            ],
          ),
        ],
      ),
    );
    return doc.save();
  }
}

