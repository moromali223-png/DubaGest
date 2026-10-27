import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/loyer_widgets.dart';

class EcheanceDetailsPage extends ConsumerWidget {
  const EcheanceDetailsPage({super.key, required this.echeanceId});
  final String echeanceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';

    final echeanceAsync = ref.watch(echeanceDetailsProvider(echeanceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'Échéance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: () => ref.invalidate(echeanceDetailsProvider(echeanceId)),
          ),
        ],
      ),
      body: echeanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(echeanceDetailsProvider(echeanceId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (echeanceDirect) {
          // Fallback sur la liste des échéances si null
          final echeance = echeanceDirect ??
              (ref.watch(echeancesLoyersProvider).value ?? const [])
                  .where((e) => e.id == echeanceId)
                  .firstOrNull;

          if (echeance == null) {
            return const MessageView(
              icon: Icons.receipt_long_outlined,
              title: 'Échéance introuvable',
              message: 'Cette échéance de loyer n\'existe pas ou a été archivée.',
            );
          }

          final biens = ref.watch(biensListProvider).value ?? const [];
          final contacts = ref.watch(contactsProvider).value ?? const [];
          final contrats = ref.watch(contratsListProvider).value ?? const [];
          final documents = ref.watch(documentsProvider).value ?? const [];

          final bien = biens.where((b) => b.id == echeance.bienId).firstOrNull;
          final locataire = contacts.where((c) => c.id == echeance.locataireId).firstOrNull;
          final contrat = contrats.where((c) => c.id == echeance.contratId).firstOrNull;

          final estEnRetard = echeance.estEnRetardCalcule(DateTime.now());
          final dateExigibiliteFormat =
              '${echeance.dateExigibilite.day.toString().padLeft(2, '0')}/${echeance.dateExigibilite.month.toString().padLeft(2, '0')}/${echeance.dateExigibilite.year}';
          final dateEmissionFormat =
              '${echeance.dateEmission.day.toString().padLeft(2, '0')}/${echeance.dateEmission.month.toString().padLeft(2, '0')}/${echeance.dateEmission.year}';

          final quittanceDoc = echeance.quittanceDocumentId != null
              ? documents.where((d) => d.id == echeance.quittanceDocumentId).firstOrNull
              : null;

          final recusDocs = documents
              .where((d) => echeance.recuDocumentIds.contains(d.id))
              .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // 1. CARTE PRINCIPALE : STATUT & MONTANTS
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: estEnRetard && !echeance.estSolde
                        ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                        : AppColors.border,
                    width: 1.5,
                  ),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    echeance.reference,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    echeance.periodeLibelle,
                                    style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          StatutEcheanceBadge(statut: echeance.statut, estEnRetard: estEnRetard),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ProgressionReglementBar(
                        montantRegle: echeance.montantRegle,
                        totalDu: echeance.totalDu,
                      ),
                      const SizedBox(height: 14),

                      // Grille financière
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildLigneMontant(
                              'Loyer net mensuel',
                              context.l10n.montant(echeance.loyerNet, devise),
                              AppColors.ink,
                            ),
                            if (echeance.charges > 0) ...[
                              const SizedBox(height: 6),
                              _buildLigneMontant(
                                'Provisions charges locatives',
                                context.l10n.montant(echeance.charges, devise),
                                AppColors.muted,
                              ),
                            ],
                            const Divider(height: 16),
                            _buildLigneMontant(
                              'Total exigible',
                              context.l10n.montant(echeance.totalDu, devise),
                              AppColors.ink,
                              estGras: true,
                            ),
                            const SizedBox(height: 6),
                            _buildLigneMontant(
                              'Montant réglé',
                              context.l10n.montant(echeance.montantRegle, devise),
                              const Color(0xFF10B981),
                              estGras: true,
                            ),
                            if (!echeance.estSolde) ...[
                              const SizedBox(height: 6),
                              _buildLigneMontant(
                                'Reste à payer',
                                context.l10n.montant(echeance.resteAPayer, devise),
                                estEnRetard ? const Color(0xFFEF4444) : const Color(0xFFDF9540),
                                estGras: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Dates clés
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Émis le : $dateEmissionFormat', style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                          Row(
                            children: [
                              Icon(
                                estEnRetard ? Icons.alarm_on_rounded : Icons.event_outlined,
                                size: 14,
                                color: estEnRetard ? const Color(0xFFEF4444) : AppColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Exigibilité : $dateExigibiliteFormat',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: estEnRetard ? const Color(0xFFEF4444) : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. LOCATAIRE
              _buildSectionTitre(context, 'Locataire redevable', Icons.person_outline_rounded),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      if (locataire != null)
                        ContactAvatar(contact: locataire, radius: 22)
                      else
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.background,
                          child: Icon(Icons.person_outline_rounded, color: AppColors.muted),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              locataire?.nomAffiche ?? 'Locataire (#${echeance.locataireId.substring(0, 6)})',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            if (locataire?.telephone != null)
                              Text(
                                'Tél : ${locataire!.telephone!}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: const Text('Fiche'),
                        onPressed: () => context.push(Routes.locataireDetails(echeance.locataireId)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. BIEN LOUÉ & CONTRAT DE BAIL
              _buildSectionTitre(context, 'Bien & Contrat de bail', Icons.home_work_outlined),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bien?.nom ?? 'Bien (#${echeance.bienId.substring(0, 6)})',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                                if (bien?.adresseComplete != null && bien!.adresseComplete.isNotEmpty)
                                  Text(
                                    bien.adresseComplete,
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Bien'),
                            onPressed: () => context.push(Routes.bienDetails(echeance.bienId)),
                          ),
                        ],
                      ),
                      if (contrat != null) ...[
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bail : ${contrat.reference}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'Exigibilité contractuelle le ${contrat.termePaiementJour} du mois',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.history_edu_rounded, size: 16),
                              label: const Text('Bail'),
                              onPressed: () => context.push(Routes.contratDetails(contrat.id)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. PIÈCES JUSTIFICATIVES & DOCUMENTS ÉMIS
              _buildSectionTitre(context, 'Documents & Justificatifs', Icons.description_outlined),
              if (quittanceDoc != null || echeance.quittanceDocumentId != null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
                  ),
                  color: const Color(0xFF10B981).withValues(alpha: 0.05),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981)),
                    ),
                    title: Text(
                      'Quittance de loyer ${quittanceDoc != null ? "N° ${quittanceDoc.numero}" : ""}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                    subtitle: const Text(
                      'Loyer soldé - Quittance officielle avec QR-Code et signature prête.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                    trailing: TextButton.icon(
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Voir'),
                      onPressed: () {
                        final docId = echeance.quittanceDocumentId ?? quittanceDoc?.id;
                        if (docId != null) {
                          context.push(Routes.document(docId));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

              if (recusDocs.isNotEmpty) ...[
                for (final recu in recusDocs) ...[
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    color: AppColors.surface,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF01226C).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_outlined, color: Color(0xFF01226C)),
                      ),
                      title: Text(
                        'Reçu d\'acompte N° ${recu.numero}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        'Acompte versé : ${context.l10n.montant(recu.montant, devise)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: const Text('Voir'),
                        onPressed: () => context.push(Routes.document(recu.id)),
                      ),
                    ),
                  ),
                ],
              ],

              if (quittanceDoc == null && echeance.quittanceDocumentId == null && recusDocs.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  color: AppColors.surface,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: AppColors.muted, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aucune pièce justificative émise pour le moment. En enregistrant un encaissement, une quittance de loyer ou un reçu d\'acompte conforme sera automatiquement généré.',
                            style: TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // 5. ACTION D'ENCAISSEMENT
              if (!echeance.estSolde)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 20),
                  label: Text(
                    'Encaisser un versement (${context.l10n.montant(echeance.resteAPayer, devise)} restant)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => context.push(
                    Routes.loyerRecevoirAvec(
                      echeanceId: echeance.id,
                      bienId: echeance.bienId,
                      locataireId: echeance.locataireId,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text(
                        'Échéance de loyer intégralement acquittée',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitre(BuildContext context, String titre, IconData icone) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 16, color: const Color(0xFF01226C)),
          const SizedBox(width: 8),
          Text(
            titre,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLigneMontant(String label, String montant, Color couleur, {bool estGras = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: estGras ? 13 : 12,
            fontWeight: estGras ? FontWeight.w700 : FontWeight.w500,
            color: estGras ? AppColors.ink : AppColors.muted,
          ),
        ),
        Text(
          montant,
          style: TextStyle(
            fontSize: estGras ? 14 : 12.5,
            fontWeight: estGras ? FontWeight.w900 : FontWeight.w700,
            color: couleur,
          ),
        ),
      ],
    );
  }
}
