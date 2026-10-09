import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/localization/l10n.dart';
import '../../../app/router/routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/state_views.dart';
import '../../contacts/domain/entities/contact.dart';
import '../../documents/presentation/pdf/recu_pdf.dart';
import '../../entreprise/presentation/providers/contexte_providers.dart';
import '../../entreprise/presentation/widgets/espace_selector.dart';
import '../../finances/domain/entities/finances.dart';
import '../../finances/domain/services/etat_finances.dart';
import '../../finances/domain/usecases/gerer_finances.dart';
import '../../finances/presentation/providers/finances_providers.dart';
import '../../finances/presentation/widgets/finances_widgets.dart';
import '../../tableau_de_bord/domain/tableau_de_bord.dart';
import '../../tableau_de_bord/presentation/tableau_de_bord_page.dart';
import '../domain/rapports.dart';

/// Rapport prêt à afficher ou à exporter : mêmes chiffres à l'écran et en PDF.
class TableauRapport {
  const TableauRapport({
    required this.titre,
    required this.periode,
    required this.entetes,
    required this.lignes,
    this.numeriques = const {},
    this.totaux,
  });

  final String titre;
  final String periode;
  final List<String> entetes;
  final List<List<String>> lignes;

  /// Index des colonnes de montants (alignées à droite).
  final Set<int> numeriques;
  final List<String>? totaux;
}

extension RapportsLabels on AppLocalizations {
  String titreRapport(TypeRapport t) => switch (t) {
        TypeRapport.tresorerie => reportCashJournal,
        TypeRapport.depenses => reportExpenses,
        TypeRapport.balanceAgee => reportAgedReceivables,
        TypeRapport.caisses => reportCashClosings,
      };

  String descriptionRapport(TypeRapport t) => switch (t) {
        TypeRapport.tresorerie => reportCashJournalHint,
        TypeRapport.depenses => reportExpensesHint,
        TypeRapport.balanceAgee => reportAgedReceivablesHint,
        TypeRapport.caisses => reportCashClosingsHint,
      };
}

/// Rapports visibles selon les droits (la donnée sous-jacente doit l'être).
List<TypeRapport> rapportsAutorises(DroitsFinances d) => [
      if (d.voirPaiements) TypeRapport.tresorerie,
      if (d.voirDepenses) TypeRapport.depenses,
      if (d.voirCreances) TypeRapport.balanceAgee,
      if (d.voirCaisse) TypeRapport.caisses,
    ];

TableauRapport construireRapport(
  TypeRapport type,
  EtatFinances etat, {
  required AppLocalizations l10n,
  required PeriodeTableau periode,
  required DateTime maintenant,
  required Map<String, Contact> contacts,
  required String devise,
}) {
  final (debut, fin) = TableauDeBord.bornes(periode, maintenant);
  final n = NumberFormat.decimalPattern(l10n.localeName);
  final date = DateFormat.yMd(l10n.localeName);
  String m(int v) => n.format(v);
  final libellePeriode = type == TypeRapport.balanceAgee
      ? l10n.reportAtDate(l10n.date(maintenant))
      : l10n.reportPeriod(l10n.date(debut), l10n.date(fin));
  String contact(String? id) => id == null ? l10n.financeNoContact : (contacts[id]?.nomAffiche ?? '—');

  switch (type) {
    case TypeRapport.tresorerie:
      final j = Rapports.tresorerie(etat, debut, fin);
      return TableauRapport(
        titre: l10n.reportCashJournal,
        periode: libellePeriode,
        entetes: [l10n.docDate, l10n.financeContact, l10n.paymentMode, l10n.paymentIn, l10n.paymentOut],
        numeriques: {3, 4},
        lignes: [
          for (final x in j.lignes)
            [
              date.format(x.paiement.datePaiement.toLocal()),
              [
                if (x.paiement.estAnnulation) l10n.paymentCancellation else contact(x.paiement.contactId),
                if (x.annule) '(${l10n.paymentCancelled})',
              ].join(' '),
              l10n.modePaiement(x.paiement.mode),
              x.paiement.sens == SensPaiement.entree ? m(x.paiement.montant) : '',
              x.paiement.sens == SensPaiement.sortie ? m(x.paiement.montant) : '',
            ],
        ],
        totaux: [l10n.reportTotal, l10n.reportNet(m(j.solde)), '', m(j.entrees), m(j.sorties)],
      );
    case TypeRapport.depenses:
      final lignes = Rapports.depenses(etat, debut, fin);
      return TableauRapport(
        titre: l10n.reportExpenses,
        periode: libellePeriode,
        entetes: [l10n.expenseCategory, l10n.reportCount, l10n.debtTotal],
        numeriques: {1, 2},
        lignes: [for (final x in lignes) [l10n.categorieDepense(x.categorie), '${x.nombre}', m(x.montant)]],
        totaux: [
          l10n.reportTotal,
          '${lignes.fold(0, (t, x) => t + x.nombre)}',
          m(lignes.fold(0, (t, x) => t + x.montant)),
        ],
      );
    case TypeRapport.balanceAgee:
      final lignes = Rapports.balanceAgee(etat, maintenant);
      int somme(int Function(LigneBalance) f) => lignes.fold(0, (t, x) => t + f(x));
      return TableauRapport(
        titre: l10n.reportAgedReceivables,
        periode: libellePeriode,
        entetes: [
          l10n.financeContact,
          l10n.reportNotDue,
          l10n.reportDaysRange(1, 30),
          l10n.reportDaysRange(31, 60),
          l10n.reportDaysRange(61, 90),
          l10n.reportDaysOver(90),
          l10n.debtTotal,
        ],
        numeriques: {1, 2, 3, 4, 5, 6},
        lignes: [
          for (final x in lignes)
            [contact(x.contactId), m(x.nonEchu), m(x.jours30), m(x.jours60), m(x.jours90), m(x.plus90), m(x.total)],
        ],
        totaux: [
          l10n.reportTotal,
          m(somme((x) => x.nonEchu)),
          m(somme((x) => x.jours30)),
          m(somme((x) => x.jours60)),
          m(somme((x) => x.jours90)),
          m(somme((x) => x.plus90)),
          m(somme((x) => x.total)),
        ],
      );
    case TypeRapport.caisses:
      final lignes = Rapports.caisses(etat, debut, fin);
      return TableauRapport(
        titre: l10n.reportCashClosings,
        periode: libellePeriode,
        entetes: [l10n.moduleFinancesCaisse, l10n.reportClosedOn, l10n.reportExpected, l10n.cashCounted, l10n.reportGap],
        numeriques: {2, 3, 4},
        lignes: [
          for (final x in lignes)
            [
              x.caisse.nom,
              date.format(x.session.fermeeLe!.toLocal()),
              x.session.soldeTheorique == null ? '…' : m(x.session.soldeTheorique!),
              m(x.session.soldeReel ?? 0),
              x.session.ecart == null ? '…' : m(x.session.ecart!),
            ],
        ],
        totaux: [
          l10n.reportTotal,
          '',
          '',
          '',
          m(lignes.fold(0, (t, x) => t + (x.session.ecart ?? 0))),
        ],
      );
  }
}

/// PDF d'un rapport (A4 paysage), dans la langue de l'interface.
Future<Uint8List> genererRapportPdf(
  TableauRapport t, {
  required String langue,
  required String entreprise,
  required String devise,
  required String genereLe,
}) async {
  await initializeDateFormatting(langue);
  final p = await PolicesPdf.charger();
  final arabe = langue == 'ar';
  final doc = pw.Document(title: t.titre, author: entreprise, creator: 'DubaGest');
  doc.addPage(pw.MultiPage(
    pageTheme: pw.PageTheme(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      textDirection: arabe ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      theme: pw.ThemeData.withFont(
        base: arabe ? p.arabe : p.latin,
        bold: arabe ? p.arabeGras : p.latinGras,
        fontFallback: arabe ? [p.latin, p.latinGras] : [p.arabe, p.arabeGras],
      ),
    ),
    header: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(entreprise, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      pw.Text(t.titre, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text('${t.periode} · ${devise == 'XOF' ? 'FCFA' : devise}', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 10),
    ]),
    footer: (c) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(genereLe, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      pw.Text('${c.pageNumber} / ${c.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]),
    build: (_) => [
      pw.TableHelper.fromTextArray(
        headers: t.entetes,
        data: [...t.lignes, ?t.totaux],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE6F4EC)),
        cellAlignments: {for (final i in t.numeriques) i: pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE1E8E4)),
      ),
    ],
  ));
  return doc.save();
}

/// Liste des rapports : période et espace de travail communs.
class RapportsPage extends ConsumerWidget {
  const RapportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final periode = ref.watch(periodeTableauProvider);
    final types = rapportsAutorises(ref.watch(droitsFinancesProvider));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleCommunRapports)),
      body: ResponsiveBody(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const EspaceSelector(),
                SegmentedButton<PeriodeTableau>(
                  segments: [
                    ButtonSegment(value: PeriodeTableau.septJours, label: Text(l10n.dashboard7Days)),
                    ButtonSegment(value: PeriodeTableau.trenteJours, label: Text(l10n.dashboard30Days)),
                    ButtonSegment(value: PeriodeTableau.moisEnCours, label: Text(l10n.dashboardMonth)),
                  ],
                  selected: {periode},
                  onSelectionChanged: (s) => ref.read(periodeTableauProvider.notifier).choisir(s.first),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (types.isEmpty) EmptyView(icon: Icons.lock_outline, message: l10n.reportNone),
            for (final t in types)
              Card(
                child: ListTile(
                  key: Key('rapport-${t.name}'),
                  leading: const Icon(Icons.table_chart_outlined, color: AppColors.green),
                  title: Text(l10n.titreRapport(t)),
                  subtitle: Text(l10n.descriptionRapport(t)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.rapport(t.name)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Un rapport à l'écran, exportable en PDF (impression, partage).
class RapportPage extends ConsumerWidget {
  const RapportPage({super.key, required this.type});
  final TypeRapport type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final etat = ref.watch(etatFinancesEspaceProvider);
    final contacts = ref.watch(contactsParIdProvider).value ?? const {};
    final devise = ref.watch(deviseProvider);
    final rapport = etat.whenData((e) => construireRapport(
          type,
          e,
          l10n: l10n,
          periode: ref.watch(periodeTableauProvider),
          maintenant: DateTime.now(),
          contacts: contacts,
          devise: devise,
        ));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.titreRapport(type)),
        actions: [
          if (rapport.value case final t?)
            IconButton(
              key: const Key('rapport-pdf'),
              tooltip: l10n.reportExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () {
                final entreprise = ref.read(contexteActifProvider)?.entreprise?.nom ?? '';
                final genereLe = l10n.reportGeneratedOn(l10n.dateTime(DateTime.now()));
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(t.titre)),
                    body: PdfPreview(
                      build: (_) => genererRapportPdf(t,
                          langue: l10n.localeName, entreprise: entreprise, devise: devise, genereLe: genereLe),
                      pdfFileName: '${t.titre}.pdf',
                      canChangePageFormat: false,
                      canChangeOrientation: false,
                      canDebug: false,
                    ),
                  ),
                ));
              },
            ),
        ],
      ),
      body: AsyncValueView(
        value: rapport,
        onRetry: () => ref.invalidate(etatFinancesProvider),
        data: (t) => ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(t.periode, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: AppSpacing.sm),
            if (t.lignes.isEmpty)
              EmptyView(icon: Icons.table_rows_outlined, message: l10n.reportEmpty)
            else
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: const Key('rapport-tableau'),
                    columns: [
                      for (final (i, e) in t.entetes.indexed)
                        DataColumn(label: Text(e), numeric: t.numeriques.contains(i)),
                    ],
                    rows: [
                      for (final l in t.lignes) DataRow(cells: [for (final c in l) DataCell(Text(c))]),
                      if (t.totaux case final tot?)
                        DataRow(cells: [
                          for (final c in tot) DataCell(Text(c, style: const TextStyle(fontWeight: FontWeight.w800))),
                        ]),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
