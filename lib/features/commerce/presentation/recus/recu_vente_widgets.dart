import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../widgets/commerce_widgets.dart';
import 'recu_vente.dart';
import 'recu_vente_pdf.dart';

/// Couleurs de la charte DubaGest utilisées sur le reçu.
abstract final class CouleursRecu {
  static const bleu = Color(0xFF01226C);
  static const or = Color(0xFFDF9540);
  static const fond = Color(0xFFF7F9FC);
  static const texte = Color(0xFF172033);
  static const texteSecondaire = Color(0xFF64748B);
}

(Color, Color, IconData) couleursStatutRecu(StatutRecu s) => switch (s) {
      StatutRecu.paye => (AppColors.positive, AppColors.positiveSoft, Icons.check_circle_rounded),
      StatutRecu.partiel => (AppColors.warning, AppColors.warningSoft, Icons.timelapse_rounded),
      StatutRecu.credit => (AppColors.warning, AppColors.warningSoft, Icons.schedule_rounded),
      StatutRecu.annule => (AppColors.negative, AppColors.negativeSoft, Icons.block_rounded),
    };

/// Pastille de statut : icône + texte + couleur (jamais la couleur seule).
class StatutRecuBadge extends StatelessWidget {
  const StatutRecuBadge({super.key, required this.statut, this.compact = false});
  final StatutRecu statut;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (fg, bg, icone) = couleursStatutRecu(statut);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: compact ? 12 : 15, color: fg),
        const SizedBox(width: 4),
        Text(libelleStatutRecu(context.l10n, statut),
            style: TextStyle(color: fg, fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Reçu à l'écran, présenté comme un ticket : client → reçu → total → paiement.
class RecuVenteTicket extends ConsumerWidget {
  const RecuVenteTicket({super.key, required this.recu});
  final DonneesRecu recu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final d = recu;
    final locale = Localizations.localeOf(context).toString();
    String m(int v) => l10n.montant(v, d.devise);
    const gris = TextStyle(color: CouleursRecu.texteSecondaire, fontSize: 12.5);
    const pointille = _Pointille();

    Widget info(String label, String valeur, {bool fort = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 92, child: Text(label, style: gris)),
            Expanded(
              child: Text(valeur,
                  style: TextStyle(
                      fontWeight: fort ? FontWeight.w800 : FontWeight.w600, color: CouleursRecu.texte, fontSize: 14)),
            ),
          ]),
        );
    Widget montantLigne(String label, String valeur, {TextStyle? style}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [Expanded(child: Text(label, style: style)), Text(valeur, style: style)]),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0F172033), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.logo != null)
                  Center(child: Image.memory(d.logo!, height: 44, fit: BoxFit.contain, gaplessPlayback: true)),
                if (d.logo != null) const SizedBox(height: 6),
                Text(d.entreprise,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CouleursRecu.bleu)),
                Text('${l10n.rcpShop} : ${d.boutique}', textAlign: TextAlign.center, style: gris),
                if (d.adresse case final a? when a.isNotEmpty) Text(a, textAlign: TextAlign.center, style: gris),
                if (d.telephone case final t? when t.isNotEmpty)
                  Text(l10n.docPhone(t), textAlign: TextAlign.center, style: gris),
                pointille,
                Center(
                  child: Text(l10n.rcpSaleReceipt,
                      style: const TextStyle(
                          letterSpacing: 1.2, fontWeight: FontWeight.w800, color: CouleursRecu.bleu, fontSize: 13)),
                ),
                const SizedBox(height: 2),
                Center(
                  child: SelectableText(
                    d.numero ?? l10n.rcpNumberPending,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: d.numero == null ? 13 : 20,
                      color: d.numero == null ? CouleursRecu.texteSecondaire : CouleursRecu.texte,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                info(l10n.rcpDate,
                    '${DateFormat.yMd(locale).format(d.date)} · ${DateFormat.Hm(locale).format(d.date)}'),
                info(l10n.comCustomer,
                    d.client == null
                        ? l10n.rcpCounterCustomer
                        : [d.client, d.clientTelephone].whereType<String>().join(' · '),
                    fort: d.client != null),
                if (d.vendeur != null) info(l10n.comSeller, d.vendeur!),
                pointille,
                for (final x in d.lignes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.produit,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: CouleursRecu.texte)),
                          Text('${x.quantite} × ${m(x.prixUnitaire)}', style: gris),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(m(x.montant), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                pointille,
                if (d.remise > 0) ...[
                  montantLigne(l10n.rcpSubtotal, m(d.sousTotal)),
                  montantLigne(l10n.comDiscount, '− ${m(d.remise)}'),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: CouleursRecu.fond, borderRadius: BorderRadius.circular(10)),
                  child: montantLigne(
                    l10n.comTotal.toUpperCase(),
                    m(d.total),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: CouleursRecu.texte),
                  ),
                ),
                const SizedBox(height: 10),
                if (d.paiement case final p? when p.isNotEmpty) info(l10n.comPayment, p),
                info(l10n.rcpPaid, m(d.paye)),
                if (d.statut != StatutRecu.annule && d.reste > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: CouleursRecu.or.withValues(alpha: 0.10),
                      border: Border.all(color: CouleursRecu.or, width: 1.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: montantLigne(
                      l10n.rcpRemainingToPay,
                      m(d.reste),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: CouleursRecu.texte, fontSize: 16),
                    ),
                  )
                else if (d.statut != StatutRecu.annule)
                  info(l10n.rcpRemaining, m(0)),
                pointille,
                if (d.pied case final p? when p.isNotEmpty)
                  Text(p, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                Text(l10n.rcpThanks,
                    textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('DUBAGEST',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800, color: CouleursRecu.bleu)),
                Text(l10n.rcpTagline, textAlign: TextAlign.center, style: gris.copyWith(fontSize: 11)),
              ],
            ),
          ),
          if (d.statut == StatutRecu.annule)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.negative.withValues(alpha: 0.7), width: 3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(l10n.rcpCancelledStamp,
                          style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: AppColors.negative.withValues(alpha: 0.7))),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pointille extends StatelessWidget {
  const _Pointille();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LayoutBuilder(
          builder: (_, c) {
            final n = (c.maxWidth / 8).floor();
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [for (var i = 0; i < n; i++) Container(width: 4, height: 1.2, color: AppColors.border)],
            );
          },
        ),
      );
}

// =============================================================================
// Actions : partager, imprimer, PDF
// =============================================================================

Future<void> partagerRecu(BuildContext context, DonneesRecu d) async {
  final l10n = context.l10n;
  final langue = Localizations.localeOf(context).languageCode;
  try {
    final octets = await genererRecuVentePdf(d, l: l10n, langue: langue);
    // Partage standard du téléphone : WhatsApp, Messenger, e-mail…
    await Printing.sharePdf(bytes: octets, filename: d.nomFichier);
  } catch (e) {
    if (context.mounted) signalerErreur(context, e);
  }
}

Future<void> imprimerRecu(BuildContext context, DonneesRecu d) async {
  final l10n = context.l10n;
  final langue = Localizations.localeOf(context).languageCode;
  try {
    // Le format vient de l'imprimante choisie (A4, A5, ticket 80 mm…).
    await Printing.layoutPdf(
      name: d.nomFichier,
      format: PdfPageFormat.a5,
      onLayout: (format) => genererRecuVentePdf(d, l: l10n, langue: langue, format: format),
    );
  } catch (e) {
    if (context.mounted) signalerErreur(context, e);
  }
}

Future<void> ouvrirPdfRecu(BuildContext context, DonneesRecu d) {
  final l10n = context.l10n;
  final langue = Localizations.localeOf(context).languageCode;
  return Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final droits = ref.watch(droitsDocumentsProvider);
        return Scaffold(
          appBar: AppBar(title: Text(d.numero ?? l10n.rcpSaleReceipt)),
          body: PdfPreview(
            build: (format) => genererRecuVentePdf(d, l: l10n, langue: langue, format: format),
            initialPageFormat: PdfPageFormat.a5,
            pageFormats: const {'A5': PdfPageFormat.a5, 'A4': PdfPageFormat.a4, 'Ticket 80 mm': PdfPageFormat.roll80},
            pdfFileName: d.nomFichier,
            allowPrinting: droits.imprimer,
            allowSharing: droits.partager,
            canChangeOrientation: false,
            canDebug: false,
          ),
        );
      },
    ),
  ));
}

/// Les actions du reçu, grandes et visibles.
class ActionsRecu extends ConsumerWidget {
  const ActionsRecu({super.key, required this.recu, this.onVoir});
  final DonneesRecu recu;

  /// « Voir le reçu » (absent quand le reçu est déjà affiché).
  final VoidCallback? onVoir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsDocumentsProvider);
    final actions = <(IconData, String, VoidCallback, Key)>[
      if (onVoir != null) (Icons.visibility_outlined, l10n.rcpView, onVoir!, const Key('recu-voir')),
      if (droits.partager)
        (Icons.ios_share_rounded, l10n.rcpShare, () => partagerRecu(context, recu), const Key('recu-partager')),
      if (droits.imprimer)
        (Icons.print_outlined, l10n.rcpPrint, () => imprimerRecu(context, recu), const Key('recu-imprimer')),
      (Icons.picture_as_pdf_outlined, l10n.rcpPdf, () => ouvrirPdfRecu(context, recu), const Key('recu-pdf')),
    ];
    return Row(
      children: [
        for (final (i, (icone, libelle, action, cle)) in actions.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Material(
              color: i == 0 ? CouleursRecu.bleu : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: i == 0 ? CouleursRecu.bleu : AppColors.border),
              ),
              child: InkWell(
                key: cle,
                borderRadius: BorderRadius.circular(14),
                onTap: action,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icone, color: i == 0 ? Colors.white : CouleursRecu.bleu),
                    const SizedBox(height: 4),
                    Text(libelle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: i == 0 ? Colors.white : CouleursRecu.texte,
                        )),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
