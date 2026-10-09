import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../domain/entities/document.dart';
import '../pdf/recu_pdf.dart';
import '../providers/documents_providers.dart';

extension DocumentsLabels on AppLocalizations {
  String typeDocument(TypeDocument t) => switch (t) {
        TypeDocument.recu => docTypeReceipt,
        TypeDocument.facture => docTypeInvoice,
        TypeDocument.devis => docTypeQuote,
        TypeDocument.avoir => docTypeCreditNote,
      };
}

/// Documents émis (reçus…), recherche par numéro ou par nom.
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = ref.watch(documentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.moduleCommunDocuments), actions: const [SyncStatusButton()]),
      body: ResponsiveBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: TextField(
                key: const Key('documents-recherche'),
                decoration: InputDecoration(hintText: l10n.docSearchHint, prefixIcon: const Icon(Icons.search)),
                onChanged: (v) => setState(() => _recherche = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: AsyncValueView(
                value: documents,
                onRetry: () => ref.invalidate(documentsProvider),
                isEmpty: (list) => list.isEmpty,
                emptyMessage: l10n.docEmpty,
                data: (list) {
                  bool garde(Document d) =>
                      _recherche.isEmpty ||
                      d.numero.toLowerCase().contains(_recherche) ||
                      ((d.contenu['contact'] as Map?)?['nom'] as String? ?? '').toLowerCase().contains(_recherche);
                  final visibles = list.where(garde).toList();
                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final d = visibles[i];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.greenSoft,
                            foregroundColor: AppColors.green,
                            child: Icon(Icons.receipt_outlined, size: 20),
                          ),
                          title: Text(d.numero, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text([
                            l10n.typeDocument(d.type),
                            if ((d.contenu['contact'] as Map?)?['nom'] case final String nom) nom,
                            l10n.date(d.date),
                            if (d.refuse) l10n.financeRejectedShort,
                          ].join(' · ')),
                          trailing: Montant(d.montant),
                          onTap: () => context.push(Routes.document(d.id)),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aperçu du document ; imprimer et partager (WhatsApp, e-mail…) selon les droits.
class DocumentPage extends ConsumerWidget {
  const DocumentPage({super.key, required this.documentId});
  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsDocumentsProvider);
    final documents = ref.watch(documentsProvider);
    final d = documents.value?.where((x) => x.id == documentId).firstOrNull;
    final etat = ref.watch(etatFinancesProvider).value;
    final paiement = d?.origineId == null ? null : etat?.paiement(d!.origineId!);
    final annule = paiement != null && etat!.estAnnule(paiement);
    final logo = ref.watch(logoEntrepriseProvider).value;

    return Scaffold(
      appBar: AppBar(title: Text(d?.numero ?? l10n.docTypeReceipt), actions: const [SyncStatusButton()]),
      body: d == null
          ? (documents.isLoading ? const LoadingView() : EmptyView(message: l10n.financeNotFound))
          : Column(
              children: [
                if (d.refuse)
                  EcritureRefuseeBanniere(
                    status: d.syncStatus,
                    onRetirer: () async {
                      await ref.read(retirerDocumentProvider).call(d.id);
                      if (context.mounted) context.pop();
                    },
                  ),
                Expanded(
                  child: PdfPreview(
                    key: const Key('document-apercu'),
                    build: (_) => genererRecuPdf(d, annule: annule, logo: logo),
                    pdfFileName: '${d.numero}.pdf',
                    allowPrinting: droits.imprimer,
                    allowSharing: droits.partager,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                  ),
                ),
              ],
            ),
    );
  }
}
