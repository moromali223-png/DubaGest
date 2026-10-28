import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_body.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../activites/domain/entities/activite.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/presentation/providers/finances_providers.dart';
import '../../../finances/presentation/widgets/finances_widgets.dart';
import '../../domain/entities/document.dart';
import '../pdf/document_pdf_generator.dart';
import '../providers/documents_providers.dart';
import '../widgets/apercu_document_feuille_a4.dart';
import '../widgets/selection_type_document_sheet.dart';

extension DocumentsLabels on AppLocalizations {
  String typeDocument(TypeDocument t) => switch (t) {
        TypeDocument.recu => docTypeReceipt,
        TypeDocument.facture => docTypeInvoice,
        TypeDocument.devis => docTypeQuote,
        TypeDocument.avoir => docTypeCreditNote,
        TypeDocument.bonCommande => 'Bon de commande',
        TypeDocument.bonTravail => 'Ordre de travail',
        TypeDocument.quittance => 'Quittance',
        TypeDocument.contrat => 'Contrat',
      };
}

enum PeriodeFiltre {
  toutes('Toutes dates'),
  aujourdhui('Aujourd\'hui'),
  ceMois('Ce mois-ci'),
  cetteAnnee('Cette année');

  const PeriodeFiltre(this.libelle);
  final String libelle;
}

enum StatutDocumentFiltre {
  tous('Tous statuts'),
  emis('Émis / En cours'),
  paye('Soldés / Payés'),
  enRetard('En retard'),
  brouillon('Brouillons'),
  annule('Annulés');

  const StatutDocumentFiltre(this.libelle);
  final String libelle;
}

/// Bibliothèque documentaire centralisée : recherche, filtres par type, statut et période.
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _recherche = '';
  TypeDocument? _filtreType;
  PeriodeFiltre _filtrePeriode = PeriodeFiltre.toutes;
  StatutDocumentFiltre _filtreStatut = StatutDocumentFiltre.tous;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = ref.watch(documentsProvider);
    final droits = ref.watch(droitsDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moduleCommunDocuments, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        centerTitle: false,
        actions: [
          if (droits.creer)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: FilledButton.icon(
                key: const Key('documents-nouveau-btn'),
                onPressed: () => SelectionTypeDocumentSheet.show(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                label: const Text('Nouveau', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              ),
            ),
          const SyncStatusButton(),
        ],
      ),
      floatingActionButton: null,
      body: ResponsiveBody(
        child: Column(
          children: [
            // Barre de recherche modernisée
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
              child: TextField(
                key: const Key('documents-recherche'),
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: l10n.docSearchHint,
                  hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.green, size: 22),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.green.withValues(alpha: 0.3), width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.green, width: 2),
                  ),
                  suffixIcon: _recherche.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: AppColors.muted),
                          onPressed: () => setState(() => _recherche = ''),
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _recherche = v.trim().toLowerCase()),
              ),
            ),

            // Filtres par type de document (Scrollable)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('Tous documents'),
                    selected: _filtreType == null,
                    showCheckmark: true,
                    selectedColor: AppColors.greenSoft,
                    labelStyle: TextStyle(
                      color: _filtreType == null ? AppColors.green : AppColors.ink,
                      fontWeight: _filtreType == null ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _filtreType = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  for (final type in TypeDocument.values) ...[
                    ChoiceChip(
                      avatar: Icon(
                        _iconeType(type), 
                        size: 16, 
                        color: _filtreType == type ? AppColors.green : AppColors.muted
                      ),
                      label: Text(l10n.typeDocument(type)),
                      selected: _filtreType == type,
                      selectedColor: AppColors.greenSoft,
                      labelStyle: TextStyle(
                        color: _filtreType == type ? AppColors.green : AppColors.ink,
                        fontWeight: _filtreType == type ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (sel) {
                        setState(() => _filtreType = sel ? type : null);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Filtres secondaires (Période & Statut)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.muted),
                  ),
                  const SizedBox(width: 8),
                  for (final p in PeriodeFiltre.values) ...[
                    ChoiceChip(
                      label: Text(p.libelle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      selected: _filtrePeriode == p,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.greenSoft,
                      onSelected: (sel) {
                        setState(() => _filtrePeriode = sel ? p : PeriodeFiltre.toutes);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(height: 20, child: VerticalDivider(width: 1, thickness: 1)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.filter_list_rounded, size: 14, color: AppColors.muted),
                  ),
                  const SizedBox(width: 8),
                  for (final s in StatutDocumentFiltre.values) ...[
                    ChoiceChip(
                      label: Text(s.libelle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      selected: _filtreStatut == s,
                      visualDensity: VisualDensity.compact,
                      selectedColor: AppColors.greenSoft,
                      onSelected: (sel) {
                        setState(() => _filtreStatut = sel ? s : StatutDocumentFiltre.tous);
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Liste des documents
            Expanded(
              child: AsyncValueView<List<Document>>(
                value: documents,
                onRetry: () => ref.invalidate(documentsProvider),
                isEmpty: (list) => list.isEmpty,
                emptyMessage: l10n.docEmpty,
                data: (list) {
                  final now = DateTime.now();

                  bool correspond(Document d) {
                    final c = d.contenu;
                    final statutBrut = (c['statut'] as String?) ?? 'EMIS';
                    final dateEchRaw = c['date_echeance'] as String?;
                    final dateEch = dateEchRaw != null ? DateTime.tryParse(dateEchRaw)?.toLocal() : null;
                    final acompte = (c['acompte'] as num?) ?? 0;
                    final reste = (c['reste'] as num?) ?? (d.montant - acompte.toInt());
                    final estEnRetard = dateEch != null &&
                        dateEch.isBefore(now) &&
                        reste > 0 &&
                        statutBrut != 'ANNULE' &&
                        statutBrut != 'PAYE';

                    // Filtre type
                    if (_filtreType != null && d.type != _filtreType) return false;

                    // Filtre statut
                    switch (_filtreStatut) {
                      case StatutDocumentFiltre.tous:
                        break;
                      case StatutDocumentFiltre.emis:
                        if (statutBrut != 'EMIS' || estEnRetard) return false;
                        break;
                      case StatutDocumentFiltre.paye:
                        if (statutBrut != 'PAYE' && reste > 0) return false;
                        break;
                      case StatutDocumentFiltre.enRetard:
                        if (!estEnRetard) return false;
                        break;
                      case StatutDocumentFiltre.brouillon:
                        if (statutBrut != 'BROUILLON') return false;
                        break;
                      case StatutDocumentFiltre.annule:
                        if (statutBrut != 'ANNULE') return false;
                        break;
                    }

                    // Filtre période
                    switch (_filtrePeriode) {
                      case PeriodeFiltre.toutes:
                        break;
                      case PeriodeFiltre.aujourdhui:
                        if (d.date.year != now.year || d.date.month != now.month || d.date.day != now.day) {
                          return false;
                        }
                      case PeriodeFiltre.ceMois:
                        if (d.date.year != now.year || d.date.month != now.month) return false;
                      case PeriodeFiltre.cetteAnnee:
                        if (d.date.year != now.year) return false;
                    }

                    // Filtre texte
                    if (_recherche.isEmpty) return true;
                    if (d.numero.toLowerCase().contains(_recherche)) return true;
                    if ((d.contactNom ?? '').toLowerCase().contains(_recherche)) return true;
                    if ((d.contactTelephone ?? '').toLowerCase().contains(_recherche)) return true;
                    if ((d.titre ?? '').toLowerCase().contains(_recherche)) return true;
                    return false;
                  }

                  final visibles = list.where(correspond).toList();

                  if (visibles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 80, color: AppColors.muted.withValues(alpha: 0.15)),
                          const SizedBox(height: 16),
                          Text(
                            'Aucun document trouvé',
                            style: TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.w900, 
                              color: AppColors.ink.withValues(alpha: 0.7)
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Text(
                              'Essayez d\'ajuster vos filtres ou de modifier votre recherche.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.8), height: 1.4),
                            ),
                          ),
                          if (_filtreType != null || _filtrePeriode != PeriodeFiltre.toutes || _filtreStatut != StatutDocumentFiltre.tous || _recherche.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 32),
                              child: TextButton.icon(
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: () => setState(() {
                                  _filtreType = null;
                                  _filtrePeriode = PeriodeFiltre.toutes;
                                  _filtreStatut = StatutDocumentFiltre.tous;
                                  _recherche = '';
                                }),
                                label: const Text('Réinitialiser les filtres', style: TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visibles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final d = visibles[i];
                      final couleur = _couleurType(d.type);
                      final c = d.contenu;
                      final statutBrut = (c['statut'] as String?) ?? 'EMIS';
                      final acompte = (c['acompte'] as num?) ?? 0;
                      final reste = (c['reste'] as num?) ?? (d.montant - acompte.toInt());
                      final dateEchRaw = c['date_echeance'] as String?;
                      final dateEch = dateEchRaw != null ? DateTime.tryParse(dateEchRaw)?.toLocal() : null;
                      final estEnRetard = dateEch != null &&
                          dateEch.isBefore(now) &&
                          reste > 0 &&
                          statutBrut != 'ANNULE' &&
                          statutBrut != 'PAYE';

                      final statutCommercial = c['statut_commercial'] as String?;
                      final (Color couleurBadgeStatut, String libelleBadgeStatut) = d.type == TypeDocument.bonCommande
                          ? switch (statutCommercial ?? statutBrut) {
                              'brouillon' || 'BROUILLON' => (AppColors.muted, 'Brouillon'),
                              'a_negocier' => (const Color(0xFF2563EB), 'En négociation'),
                              'envoye' => (const Color(0xFF7C3AED), 'Envoyé'),
                              'contre_proposition' => (const Color(0xFFEA580C), 'Contre-prop.'),
                              'confirme' || 'CONFIRME' => (AppColors.green, 'Confirmé'),
                              'recu_partiel' => (const Color(0xFFEA580C), 'Reçu partiel'),
                              'recu' || 'PAYE' => (AppColors.green, 'Soldé / Reçu'),
                              'ANNULE' || 'annule' => (AppColors.negative, 'Annulé'),
                              _ => (AppColors.green, 'Émis'),
                            }
                          : switch (statutBrut) {
                              'ANNULE' => (AppColors.negative, 'Annulé'),
                              'BROUILLON' => (AppColors.muted, 'Brouillon'),
                              'PAYE' => (AppColors.green, 'Soldé'),
                              _ => estEnRetard
                                  ? (AppColors.negative, 'En retard')
                                  : (reste < d.montant && reste > 0
                                      ? (AppColors.warning, 'Partiel')
                                      : (AppColors.green, 'Émis')),
                            };

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push(Routes.document(d.id)),
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Barre latérale colorée
                                  Container(
                                    width: 5,
                                    decoration: BoxDecoration(
                                      color: couleur,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Ligne 1 : Type & Statut & Numéro
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: couleur.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: couleur.withValues(alpha: 0.1)),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(_iconeType(d.type), size: 12, color: couleur),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            l10n.typeDocument(d.type).toUpperCase(),
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w900,
                                                              color: couleur,
                                                              letterSpacing: 0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: couleurBadgeStatut.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        libelleBadgeStatut.toUpperCase(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight: FontWeight.w900,
                                                          color: couleurBadgeStatut,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                d.numero,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 13,
                                                  color: AppColors.ink.withValues(alpha: 0.8),
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Ligne 2 : Partenaire & Montants
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.background.withValues(alpha: 0.5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  d.type == TypeDocument.bonCommande ? Icons.storefront_rounded : Icons.person_rounded,
                                                  size: 18,
                                                  color: AppColors.muted,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      d.contactNom ?? (d.type == TypeDocument.bonCommande ? 'Fournisseur' : 'Client comptoir'),
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w900, 
                                                        fontSize: 15,
                                                        color: AppColors.ink,
                                                        letterSpacing: -0.5,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    if (d.titre case final String t when t.isNotEmpty)
                                                      Text(
                                                        t,
                                                        style: TextStyle(fontSize: 12, color: AppColors.muted.withValues(alpha: 0.8), fontWeight: FontWeight.w700),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${NumberFormat.decimalPattern('fr').format(d.montant)} FCFA',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 16,
                                                      color: AppColors.green,
                                                      letterSpacing: -0.5,
                                                    ),
                                                  ),
                                                  if (reste > 0 && reste != d.montant)
                                                    Text(
                                                      '${NumberFormat.decimalPattern('fr').format(reste)} dû',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w900,
                                                        color: estEnRetard ? AppColors.negative : AppColors.warning,
                                                        letterSpacing: -0.3,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 14),

                                          // Ligne 3 : Dates & Chevron
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.muted.withValues(alpha: 0.6)),
                                              const SizedBox(width: 6),
                                              Text(
                                                DateFormat('dd/MM/yyyy').format(d.date),
                                                style: TextStyle(
                                                  fontSize: 12, 
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.muted.withValues(alpha: 0.8)
                                                ),
                                              ),
                                              if (dateEch != null) ...[
                                                const SizedBox(width: 12),
                                                Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.muted.withValues(alpha: 0.3), shape: BoxShape.circle)),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Éch. ${DateFormat('dd/MM/yyyy').format(dateEch)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: estEnRetard ? FontWeight.w900 : FontWeight.w700,
                                                    color: estEnRetard ? AppColors.negative : AppColors.muted.withValues(alpha: 0.8),
                                                  ),
                                                ),
                                              ],
                                              const Spacer(),
                                              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.muted.withValues(alpha: 0.3)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  IconData _iconeType(TypeDocument t) => switch (t) {
        TypeDocument.recu => Icons.receipt_outlined,
        TypeDocument.facture => Icons.receipt_long,
        TypeDocument.devis => Icons.request_quote_outlined,
        TypeDocument.avoir => Icons.assignment_return_outlined,
        TypeDocument.bonCommande => Icons.shopping_cart_checkout,
        TypeDocument.bonTravail => Icons.build_circle_outlined,
        TypeDocument.quittance => Icons.home_work_outlined,
        TypeDocument.contrat => Icons.handshake_outlined,
      };

  Color _couleurType(TypeDocument t) => switch (t) {
        TypeDocument.recu => AppColors.green,
        TypeDocument.facture => AppColors.green,
        TypeDocument.devis => const Color(0xFF2563EB),
        TypeDocument.avoir => AppColors.avoir,
        TypeDocument.bonCommande => AppColors.dette,
        TypeDocument.bonTravail => const Color(0xFF0D9488),
        TypeDocument.quittance => const Color(0xFF059669),
        TypeDocument.contrat => const Color(0xFF4F46E5),
      };
}

/// Fiche détaillée et aperçu officiel du document : détails complets, aperçu PDF, impression et WhatsApp.
class DocumentPage extends ConsumerStatefulWidget {
  const DocumentPage({super.key, required this.documentId});
  final String documentId;

  @override
  ConsumerState<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends ConsumerState<DocumentPage> {
  int _onglet = 0; // 0 = Détails, 1 = Aperçu PDF / Feuille A4
  bool _modePdfVectoriel = false;

  Future<void> _telechargerPdf(Document d, bool annule, Uint8List? logo) async {
    try {
      final bytes = await genererDocumentPdf(d, annule: annule, logo: logo);
      await Printing.sharePdf(bytes: bytes, filename: '${d.numero}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement : $e')),
        );
      }
    }
  }

  void _partagerWhatsApp(BuildContext context, Document d, String entrepriseNom) {
    final contact = d.contactNom ?? (d.type == TypeDocument.bonCommande ? 'Fournisseur' : 'Client');
    final nombres = NumberFormat.decimalPattern('fr');
    final montantFmt = nombres.format(d.montant);
    final devise = (d.contenu['entreprise'] as Map?)?['devise'] ?? 'FCFA';
    final uniteDevise = devise == 'XOF' ? 'FCFA' : devise;

    final lignesMap = ((d.contenu['lignes'] as List?) ?? const []).cast<Map>();
    final lignesTexte = lignesMap.isNotEmpty
        ? lignesMap.map((l) {
            final lib = l['libelle'] ?? 'Article';
            final qte = l['quantite'] ?? 1;
            final pu = l['prix_unitaire'];
            final mt = l['montant'] ?? ((qte as num) * ((pu as num?) ?? 0)).round();
            final puStr = pu != null ? ' (${nombres.format(pu)} $uniteDevise)' : '';
            return '• $lib : ${nombres.format(qte)}x$puStr = ${nombres.format(mt)} $uniteDevise';
          }).join('\n')
        : '• Montant : $montantFmt $uniteDevise';

    final remise = (d.contenu['remise'] as num?) ?? 0;
    final acompte = (d.contenu['acompte'] as num?) ?? 0;
    final reste = (d.contenu['reste'] as num?) ?? (d.montant - acompte.toInt());

    final dateEcheanceRaw = d.contenu['date_echeance'] as String?;
    final dateLivraisonStr = dateEcheanceRaw != null
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(dateEcheanceRaw).toLocal())
        : null;

    final typeTitre = switch (d.type) {
      TypeDocument.bonCommande => 'BON DE COMMANDE FOURNISSEUR',
      TypeDocument.facture => 'FACTURE COMMERCIALE',
      TypeDocument.devis => 'DEVIS / PROFORMA',
      TypeDocument.avoir => 'NOTE D\'AVOIR',
      TypeDocument.recu => 'REÇU DE RÈGLEMENT',
      TypeDocument.bonTravail => 'ORDRE D\'INTERVENTION',
      TypeDocument.quittance => 'QUITTANCE',
      TypeDocument.contrat => 'CONTRAT',
    };

    final message = '''
📄 *$typeTitre — $entrepriseNom*
━━━━━━━━━━━━━━━━━━━━━
🔖 *N° :* ${d.numero}
📋 *Objet :* ${d.titre ?? d.type.code}
${d.type == TypeDocument.bonCommande ? "🏢 *Fournisseur :*" : "👤 *Destinataire :*"} $contact
📅 *Date d'émission :* ${DateFormat('dd/MM/yyyy').format(d.date)}
${dateLivraisonStr != null ? (d.type == TypeDocument.bonCommande ? "🚚 *Livraison souhaitée :* $dateLivraisonStr\n" : "⏳ *Date d'échéance :* $dateLivraisonStr\n") : ""}
📝 *Articles & Prestations :*
$lignesTexte

${remise > 0 ? "🏷️ *Remise :* ${nombres.format(remise)} $uniteDevise\n" : ""}💰 *TOTAL NET :* $montantFmt $uniteDevise
${acompte > 0 ? "💵 *Acompte :* ${nombres.format(acompte)} $uniteDevise\n" : ""}${reste > 0 ? "📌 *Reste à régler :* ${nombres.format(reste)} $uniteDevise\n" : ""}
${d.conditions != null && d.conditions!.isNotEmpty ? "📌 *Modalités :* ${d.conditions}\n" : ""}${d.notes != null && d.notes!.isNotEmpty ? "💬 *Notes :* ${d.notes}\n" : ""}
_Document officiel généré via DubaGest._
_${entrepriseNom}_
''';

    final tel = d.contactTelephone ?? '';
    final cleanTel = tel.replaceAll(RegExp(r'\D'), '');

    final uri = cleanTel.length >= 6
        ? Uri.parse('https://wa.me/$cleanTel?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _allerVersOrigine(BuildContext context, Document d) {
    final origineId = d.origineId;
    if (origineId == null) return;

    switch (d.origineType) {
      case 'PAIEMENT':
        context.push(Routes.paiement(origineId));
      case 'VENTE':
        context.push(Routes.vente(origineId));
      case 'PRESTATION':
        context.push(Routes.prestation(origineId));
      case 'ACHAT':
        context.push(Routes.achat(origineId));
      case 'DEPENSE':
        context.push(Routes.depense(origineId));
      default:
        break;
    }
  }

  void _ouvrirApercuModal(BuildContext context, Document d, bool annule, Uint8List? logo, String entrepriseNom) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text('${d.numero} — Feuille officielle A4'),
            actions: [
              IconButton(
                tooltip: 'Imprimer officiel',
                icon: const Icon(Icons.print),
                onPressed: () => Printing.layoutPdf(
                  onLayout: (_) => genererDocumentPdf(d, annule: annule, logo: logo),
                  name: '${d.numero}.pdf',
                ),
              ),
              IconButton(
                tooltip: 'Télécharger le PDF',
                icon: const Icon(Icons.download),
                onPressed: () => _telechargerPdf(d, annule, logo),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ApercuDocumentFeuilleA4(
              document: d,
              annule: annule,
              logo: logo,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final droits = ref.watch(droitsDocumentsProvider);
    final documents = ref.watch(documentsProvider);
    final d = documents.value?.where((x) => x.id == widget.documentId).firstOrNull;
    final etat = ref.watch(etatFinancesProvider).value;
    final paiement = d?.origineId == null ? null : etat?.paiement(d!.origineId!);
    final annule = (paiement != null && etat!.estAnnule(paiement)) || d?.contenu['statut'] == 'ANNULE';
    final logo = ref.watch(logoEntrepriseProvider).value;
    final ctx = ref.watch(contexteActifProvider);
    final entrepriseNom = ctx?.entreprise?.nom ?? 'DUBAGEST';
    final hasCommerce = ctx?.activites.any((a) => a.activite == ActiviteCode.commerce && a.estActive) ?? false;

    if (d == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.docTypeReceipt)),
        body: documents.isLoading ? const LoadingView() : EmptyView(message: l10n.financeNotFound),
      );
    }

    final c = d.contenu;
    final contactMap = (c['contact'] as Map?)?.cast<String, dynamic>();
    final lignes = ((c['lignes'] as List?) ?? const []).cast<Map>();
    final devise = (c['entreprise'] as Map?)?['devise'] ?? 'FCFA';
    final uniteDevise = devise == 'XOF' ? 'FCFA' : devise;
    final nombres = NumberFormat.decimalPattern('fr');

    final sousTotal = (c['sous_total'] as num?) ?? d.montant;
    final remise = (c['remise'] as num?) ?? 0;
    final acompte = (c['acompte'] as num?) ?? 0;
    final reste = (c['reste'] as num?) ?? (d.montant - acompte.toInt());

    final dateEcheanceRaw = c['date_echeance'] as String?;
    final dateEcheance = dateEcheanceRaw != null ? DateTime.tryParse(dateEcheanceRaw)?.toLocal() : null;
    final estEnRetard = reste > 0 && dateEcheance != null && DateTime.now().isAfter(dateEcheance);

    final statutBrut = (c['statut'] as String?) ?? 'EMIS';
    final statutCommercial = c['statut_commercial'] as String?;
    final economieTotale = (c['economie_totale'] as num?)?.toInt() ?? 0;

    final (Color couleurStatut, String libelleStatut) = d.type == TypeDocument.bonCommande
        ? switch (statutCommercial ?? statutBrut) {
            'brouillon' || 'BROUILLON' => (AppColors.muted, 'BROUILLON INTERNE'),
            'a_negocier' => (const Color(0xFF2563EB), 'EN NÉGOCIATION (PRIX PROPOSÉ)'),
            'envoye' => (const Color(0xFF7C3AED), 'ENVOYÉ AU FOURNISSEUR'),
            'contre_proposition' => (const Color(0xFFEA580C), 'CONTRE-PROPOSITION REÇUE'),
            'confirme' || 'CONFIRME' => (AppColors.green, 'COMMANDE CONFIRMÉE'),
            'recu_partiel' => (const Color(0xFFEA580C), 'RÉCEPTION PARTIELLE (ACHATS)'),
            'recu' || 'PAYE' => (AppColors.green, 'SOLDÉ / TOTALEMENT RÉCEPTIONNÉ'),
            'ANNULE' || 'annule' => (AppColors.negative, 'COMMANDE ANNULÉE'),
            _ => (AppColors.green, 'BON DE COMMANDE ÉMIS'),
          }
        : switch (statutBrut) {
            'PAYE' => (AppColors.green, 'RÉGLÉ / SOLDÉ'),
            'BROUILLON' => (AppColors.muted, 'BROUILLON'),
            'ANNULE' => (AppColors.negative, 'ANNULÉ'),
            _ => (AppColors.green, 'ÉMIS (OFFICIEL)'),
          };

    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.typeDocument(d.type)} ${d.numero}'),
        actions: const [SyncStatusButton()],
      ),
      body: Column(
        children: [
          if (d.refuse)
            EcritureRefuseeBanniere(
              status: d.syncStatus,
              onRetirer: () async {
                await ref.read(retirerDocumentProvider).call(d.id);
                if (context.mounted) context.pop();
              },
            ),

          // Sélecteur d'onglets élégant : Détails vs Aperçu de l'imprimé (PDF)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: Text(
                          d.type == TypeDocument.bonCommande ? 'Détails de la commande' : 'Détails du document',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const ButtonSegment(
                        value: 1,
                        icon: Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: Text(
                          'Aperçu de l\'imprimé (PDF)',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    selected: {_onglet},
                    onSelectionChanged: (s) => setState(() => _onglet = s.first),
                  ),
                ),
              ],
            ),
          ),

          // Contenu de la vue sélectionnée
          Expanded(
            child: _onglet == 0
                // VUE 1 : DÉTAILS DE LA COMMANDE
                ? ResponsiveBody(
                    maxWidth: 900,
                    child: ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        // 1. En-tête du Document & Statut
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isCompact = constraints.maxWidth < 460;
                                    final numeroWidget = Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            d.numero,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 18,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 16, color: AppColors.muted),
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.all(4),
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Copier le numéro',
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: d.numero));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Numéro copié dans le presse-papier')),
                                            );
                                          },
                                        ),
                                      ],
                                    );

                                    final statutWidget = Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: couleurStatut.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        libelleStatut,
                                        style: TextStyle(
                                          color: couleurStatut,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );

                                    if (isCompact) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Expanded(child: numeroWidget),
                                              const SizedBox(width: 8),
                                              statutWidget,
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  d.titre ?? l10n.typeDocument(d.type),
                                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Émis le ${DateFormat('dd/MM/yyyy').format(d.date)}',
                                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                              ),
                                            ],
                                          ),
                                          if (c['reference_metier'] case final String refMetier when refMetier.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                'Réf. externe : $refMetier',
                                                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                                              ),
                                            ),
                                        ],
                                      );
                                    }

                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              numeroWidget,
                                              const SizedBox(height: 2),
                                              Text(
                                                d.titre ?? l10n.typeDocument(d.type),
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                              ),
                                              if (c['reference_metier'] case final String refMetier when refMetier.isNotEmpty)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    'Réf. externe : $refMetier',
                                                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            statutWidget,
                                            const SizedBox(height: 6),
                                            Text(
                                              'Émis le ${DateFormat('dd/MM/yyyy').format(d.date)}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const Divider(height: 24),

                                // Actions directes en ligne
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                                      label: const Text('Aperçu du PDF'),
                                      onPressed: () => setState(() => _onglet = 1),
                                    ),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.print_outlined, size: 16),
                                      label: const Text('Imprimer'),
                                      onPressed: () => Printing.layoutPdf(
                                        onLayout: (_) => genererDocumentPdf(d, annule: annule, logo: logo),
                                        name: '${d.numero}.pdf',
                                      ),
                                    ),
                                    if (droits.partager)
                                      FilledButton.tonalIcon(
                                        icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF25D366)),
                                        label: const Text('Partager sur WhatsApp'),
                                        onPressed: () => _partagerWhatsApp(context, d, entrepriseNom),
                                      ),
                                    if (d.type == TypeDocument.bonCommande && hasCommerce)
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                                        label: const Text('Créer l\'achat / Réceptionner'),
                                        onPressed: () => context.push(
                                          Routes.achatNouveau(bonCommandeId: d.id, fournisseurId: d.contactId),
                                        ),
                                      ),
                                    if (d.origineId != null && ['PAIEMENT', 'VENTE', 'PRESTATION', 'ACHAT', 'DEPENSE'].contains(d.origineType))
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.open_in_new, size: 16),
                                        label: Text('Voir ${d.origineType.toLowerCase()}'),
                                        onPressed: () => _allerVersOrigine(context, d),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        if (d.type == TypeDocument.bonCommande && economieTotale > 0) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.greenSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.savings_outlined, color: AppColors.green, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Gain de négociation commerciale',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.green),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Vous avez obtenu une économie de ${nombres.format(economieTotale)} $uniteDevise sur cette commande par rapport au prix de référence.',
                                        style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (d.type == TypeDocument.bonCommande && (c['lieu_livraison'] as String?)?.isNotEmpty == true) ...[
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF7ED),
                                child: Icon(Icons.location_on_outlined, color: Color(0xFFEA580C)),
                              ),
                              title: const Text('Lieu / Dépôt de livraison convenu', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                              subtitle: Text(c['lieu_livraison'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],

                        // 2. Partenaire / Fournisseur ou Client
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      d.type == TypeDocument.bonCommande ? 'Fournisseur / Prestataire' : 'Destinataire / Client',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted),
                                    ),
                                    if (d.contactId != null)
                                      TextButton.icon(
                                        icon: const Icon(Icons.person_outline, size: 16),
                                        label: const Text('Voir la fiche'),
                                        onPressed: () => context.push(Routes.contact(d.contactId!)),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Builder(
                                  builder: (context) {
                                    final telContact = contactMap?['telephone'] as String? ?? d.contactTelephone;
                                    final cleanTelContact = telContact?.replaceAll(RegExp(r'\D'), '') ?? '';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: (d.type == TypeDocument.bonCommande ? AppColors.dette : AppColors.green).withValues(alpha: 0.1),
                                        child: Icon(
                                          d.type == TypeDocument.bonCommande ? Icons.storefront : Icons.person,
                                          color: d.type == TypeDocument.bonCommande ? AppColors.dette : AppColors.green,
                                        ),
                                      ),
                                      title: Text(
                                        contactMap?['nom'] ?? d.contactNom ?? 'Non spécifié',
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                      ),
                                      subtitle: Text(
                                        [
                                          if (telContact != null && telContact.isNotEmpty) telContact,
                                          if (contactMap?['email'] case final String email when email.isNotEmpty) email,
                                          if (contactMap?['adresse'] case final String adr when adr.isNotEmpty) adr,
                                        ].join(' · '),
                                      ),
                                      trailing: cleanTelContact.isNotEmpty
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.phone_outlined, size: 20, color: AppColors.green),
                                                  tooltip: 'Appeler',
                                                  onPressed: () => launchUrl(Uri.parse('tel:$cleanTelContact')),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF25D366)),
                                                  tooltip: 'WhatsApp direct',
                                                  onPressed: () => launchUrl(
                                                    Uri.parse('https://wa.me/$cleanTelContact'),
                                                    mode: LaunchMode.externalApplication,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // 3. Dates & Échéances
                        if (dateEcheance != null)
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available, color: Color(0xFFEA580C)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.type == TypeDocument.bonCommande
                                              ? 'Date de livraison souhaitée'
                                              : (d.type == TypeDocument.devis ? 'Offre valable jusqu\'au' : 'Date d\'échéance'),
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                        ),
                                        Text(
                                          DateFormat('EEEE dd MMMM yyyy', 'fr').format(dateEcheance),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (dateEcheance != null) const SizedBox(height: AppSpacing.sm),

                        // 4. Articles & Prestations commandés
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.type == TypeDocument.bonCommande
                                      ? 'Marchandises commandées & Tarifs convenus'
                                      : 'Articles & Prestations commandés',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 12),
                                if (lignes.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Aucune ligne détaillée enregistrée.', style: TextStyle(color: AppColors.muted)),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: lignes.length,
                                    separatorBuilder: (_, _) => const Divider(height: 16),
                                    itemBuilder: (_, idx) {
                                      final l = lignes[idx];
                                      final libelle = (l['libelle'] as String?) ?? 'Article ${idx + 1}';
                                      final qte = (l['quantite'] as num?) ?? 1;
                                      final uniteStr = (l['unite'] as String?)?.isNotEmpty == true ? ' ${l['unite']}' : '';
                                      final pu = l['prix_unitaire'] as num?;
                                      final prixRef = l['prix_reference'] as num?;
                                      final economieLigne = (l['economie'] as num?)?.toInt() ?? 0;
                                      final mt = (l['montant'] as num?) ?? ((qte * (pu ?? 0)).round());

                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppColors.greenSoft,
                                            child: Text(
                                              '${idx + 1}',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.green),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${nombres.format(qte)}$uniteStr × ${pu != null ? "${nombres.format(pu)} $uniteDevise" : "-"}',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                                ),
                                                if (d.type == TypeDocument.bonCommande && prixRef != null && prixRef != pu)
                                                  Text(
                                                    'Tarif réf. catalogue : ${nombres.format(prixRef)} $uniteDevise',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                                  ),
                                                if (d.type == TypeDocument.bonCommande && economieLigne > 0)
                                                  Text(
                                                    'Gain négocié : -${nombres.format(economieLigne)} $uniteDevise',
                                                    style: const TextStyle(fontSize: 11, color: AppColors.green, fontWeight: FontWeight.bold),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${nombres.format(mt)} $uniteDevise',
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // 5. Synthèse Financière
                        Card(
                          color: const Color(0xFFF8FAFC),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Sous-total brut :', style: TextStyle(color: AppColors.muted)),
                                    Text('${nombres.format(sousTotal)} $uniteDevise', style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (remise > 0) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Remise commerciale :', style: TextStyle(color: AppColors.muted)),
                                      Text('- ${nombres.format(remise)} $uniteDevise', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.negative)),
                                    ],
                                  ),
                                ],
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL NET :', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                    Text(
                                      '${nombres.format(d.montant)} $uniteDevise',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                  ],
                                ),
                                if (acompte > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Acompte / Déjà réglé :', style: TextStyle(color: AppColors.muted)),
                                      Text('${nombres.format(acompte)} $uniteDevise', style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      d.type == TypeDocument.bonCommande
                                          ? 'Solde prévisionnel à la livraison :'
                                          : (d.type == TypeDocument.avoir
                                              ? 'Avoir restant (À déduire) :'
                                              : 'Reste à percevoir (Créance client) :'),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${nombres.format(reste)} $uniteDevise',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: reste > 0
                                            ? (d.type == TypeDocument.bonCommande
                                                ? const Color(0xFFEA580C)
                                                : (d.type == TypeDocument.avoir
                                                    ? AppColors.avoir
                                                    : (estEnRetard ? AppColors.negative : AppColors.green)))
                                            : AppColors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                if (d.type == TypeDocument.bonCommande) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFED7AA)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.shield_outlined, color: Color(0xFFEA580C), size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Ce bon de commande n\'engage aucun décaissement immédiat et n\'augmente pas le stock physique. La facture et la dette réelle seront constatées lors de la réception dans le module Achats.',
                                            style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        // 6. Conditions & Notes
                        if ((d.conditions != null && d.conditions!.isNotEmpty) || (d.notes != null && d.notes!.isNotEmpty))
                          Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (d.conditions case final String cond when cond.isNotEmpty) ...[
                                    const Text('Modalités & Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Text(cond, style: const TextStyle(fontSize: 13.5)),
                                    if (d.notes != null && d.notes!.isNotEmpty) const Divider(height: 20),
                                  ],
                                  if (d.notes case final String note when note.isNotEmpty) ...[
                                    const Text('Notes complémentaires', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
                                    const SizedBox(height: 4),
                                    Text(note, style: const TextStyle(fontSize: 13.5)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        if ((d.conditions != null && d.conditions!.isNotEmpty) || (d.notes != null && d.notes!.isNotEmpty))
                          const SizedBox(height: AppSpacing.sm),

                        // 7. Passerelle vers Achats pour les bons de commande
                        if (d.type == TypeDocument.bonCommande && hasCommerce && !annule) ...[
                          Card(
                            color: const Color(0xFFFFF7ED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFFDBA74)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.inventory_2_outlined, color: Color(0xFFEA580C), size: 24),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Marchandises livrées par le fournisseur ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                            Text(
                                              'Réceptionnez les articles en stock et enregistrez la facture fournisseur.',
                                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFEA580C),
                                      minimumSize: const Size.fromHeight(46),
                                    ),
                                    icon: const Icon(Icons.arrow_forward_rounded),
                                    label: const Text('Créer l\'Achat de marchandises / Réceptionner en stock', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => context.push(
                                      Routes.achatNouveau(bonCommandeId: d.id, fournisseurId: d.contactId),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  )
                // VUE 2 : APERÇU DE L'IMPRIMÉ OFFICIEL (FEUILLE A4 & PDF)
                : Column(
                    children: [
                      Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: LayoutBuilder(
                          builder: (context, barConstraints) {
                            final pill = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.greenSoft,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _modePdfVectoriel ? Icons.picture_as_pdf : Icons.verified,
                                    size: 13,
                                    color: AppColors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _modePdfVectoriel ? 'PDF' : 'Feuille A4',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.green),
                                  ),
                                ],
                              ),
                            );

                            final actions = [
                              // Bouton Imprimer compact
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.green,
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.print, size: 15),
                                label: const Text('Imprimer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                onPressed: () => Printing.layoutPdf(
                                  onLayout: (_) => genererDocumentPdf(d, annule: annule, logo: logo),
                                  name: '${d.numero}.pdf',
                                ),
                              ),
                              const SizedBox(width: 4),

                              // Bouton Télécharger PDF
                              IconButton(
                                tooltip: 'Télécharger le PDF',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.download_rounded, size: 20),
                                onPressed: () => _telechargerPdf(d, annule, logo),
                              ),

                              // Bouton WhatsApp
                              if (droits.partager) ...[
                                const SizedBox(width: 2),
                                IconButton(
                                  tooltip: 'Partager WhatsApp',
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.chat_bubble_outline, size: 19, color: Color(0xFF25D366)),
                                  onPressed: () => _partagerWhatsApp(context, d, entrepriseNom),
                                ),
                              ],

                              // Bascule Feuille A4 / Moteur PDF
                              IconButton(
                                tooltip: _modePdfVectoriel ? 'Afficher Feuille A4' : 'Afficher Moteur PDF',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(_modePdfVectoriel ? Icons.article_outlined : Icons.picture_as_pdf_outlined, size: 19),
                                onPressed: () => setState(() => _modePdfVectoriel = !_modePdfVectoriel),
                              ),

                              // Plein écran
                              IconButton(
                                tooltip: 'Plein écran',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.fullscreen, size: 20),
                                onPressed: () => _ouvrirApercuModal(context, d, annule, logo, entrepriseNom),
                              ),
                            ];

                            if (barConstraints.maxWidth < 480) {
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    pill,
                                    const SizedBox(width: 8),
                                    ...actions,
                                  ],
                                ),
                              );
                            }

                            return Row(
                              children: [
                                pill,
                                const Spacer(),
                                ...actions,
                              ],
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: !_modePdfVectoriel
                            ? SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                child: ApercuDocumentFeuilleA4(
                                  document: d,
                                  annule: annule,
                                  logo: logo,
                                ),
                              )
                            : PdfPreview(
                                key: ValueKey('pdf-${d.id}'),
                                build: (format) => genererDocumentPdf(d, annule: annule, logo: logo),
                                pdfFileName: '${d.numero}.pdf',
                                allowPrinting: true,
                                allowSharing: true,
                                canChangePageFormat: false,
                                canChangeOrientation: false,
                                canDebug: false,
                                loadingWidget: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 12),
                                      Text('Chargement du rendu PDF vectoriel...'),
                                    ],
                                  ),
                                ),
                                onError: (context, error) => Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.info_outline, size: 48, color: AppColors.green),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Le moteur PDF du navigateur est restreint.\nVous pouvez afficher la feuille A4 officielle ou imprimer directement :',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            FilledButton.icon(
                                              icon: const Icon(Icons.article),
                                              label: const Text('Voir Feuille A4'),
                                              onPressed: () => setState(() => _modePdfVectoriel = false),
                                            ),
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.print),
                                              label: const Text('Imprimer directement'),
                                              onPressed: () => Printing.layoutPdf(
                                                onLayout: (_) => genererDocumentPdf(d, annule: annule, logo: logo),
                                                name: '${d.numero}.pdf',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

