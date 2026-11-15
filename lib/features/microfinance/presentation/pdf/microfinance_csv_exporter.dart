import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/microfinance_models.dart';

/// Exportateur CSV compatible Microsoft Excel / Google Sheets (UTF-8 avec BOM).
abstract final class MicrofinanceCsvExporter {
  static String _esc(Object? v) {
    final s = (v?.toString() ?? '').replaceAll('"', '""');
    return '"$s"';
  }

  static String _row(List<Object?> cols) => cols.map(_esc).join(';');
  static String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd HH:mm').format(d.toLocal());

  static String exporterPrets({
    required List<MicrofinanceLoan> loans,
    required Map<String, MicrofinanceBorrower> borrowersById,
  }) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row([
      'Reference',
      'Emprunteur',
      'Telephone',
      'Date Octroi',
      'Montant Accorde',
      'Methode Interet',
      'Taux / Fixe',
      'Interet Total',
      'Total a Rembourser',
      'Capital Rembourse',
      'Interet Rembourse',
      'Reste a Payer',
      'Frequence',
      'Nb Echeances',
      'Statut',
    ]));
    for (final l in loans) {
      final b = borrowersById[l.borrowerId];
      buf.writeln(_row([
        l.reference,
        b?.nomComplet ?? '',
        b?.telephone ?? '',
        _fmtDate(l.dateOctroi),
        l.montantAccorde,
        l.methodeInteret.libelle('fr'),
        l.montantInteretFixe > 0 ? l.montantInteretFixe : l.tauxInteret,
        l.montantInteretTotal,
        l.montantTotalARembourser,
        l.capitalRembourse,
        l.interetRembourse,
        l.resteAPayerTotal,
        l.frequence.libelle('fr'),
        l.nombreEcheances,
        l.statut.libelle('fr'),
      ]));
    }
    return buf.toString();
  }

  static String exporterTransactions({
    required List<MicrofinanceTransaction> transactions,
    required Map<String, MicrofinanceAccount> accountsById,
  }) {
    final buf = StringBuffer('\uFEFF');
    buf.writeln(_row([
      'Reference',
      'Date',
      'Type',
      'Sens',
      'Compte',
      'Montant',
      'Part Capital',
      'Part Interet',
      'Mode Paiement',
      'Libelle',
      'Observations',
    ]));
    for (final t in transactions) {
      buf.writeln(_row([
        t.reference,
        _fmtDate(t.dateTransaction),
        t.typeTransaction.libelle('fr'),
        t.sens.code,
        accountsById[t.accountId]?.nom ?? '',
        t.montant,
        t.partCapital,
        t.partInteret,
        t.modePaiement.libelle('fr'),
        t.libelle,
        t.observations ?? '',
      ]));
    }
    return buf.toString();
  }

  /// Affiche une boîte d'export CSV permettant de copier vers Excel ou télécharger directement.
  static Future<void> afficherEtExporter(
    BuildContext context, {
    required String titre,
    required String csvContent,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Format CSV compatible Excel (séparateur « ; », UTF-8 BOM).',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvContent,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: csvContent));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Données CSV copiées dans le presse-papiers.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copier pour Excel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(
                        'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvContent)}',
                      );
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Télécharger .CSV'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

