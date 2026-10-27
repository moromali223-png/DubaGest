import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/sync_status_button.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../commerce/presentation/widgets/commerce_widgets.dart' show montant;
import '../../domain/entities/metier_template.dart';
import '../../domain/entities/prestation.dart';
import '../services_providers.dart';
import '../widgets/bon_prise_en_charge_dialog.dart';
import '../widgets/prestation_photos_section.dart';
import '../widgets/prestation_rappel_dialog.dart';
import '../widgets/services_widgets.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';

/// Fiche détaillée d'une prestation / ordre de travail multi-métiers.
/// Double dimension indépendante : Statut Travail vs Statut Paiement.
class PrestationDetailsPage extends ConsumerWidget {
  const PrestationDetailsPage({super.key, required this.prestationId});
  final String prestationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prestationsAsync = ref.watch(prestationsProvider);
    final historiqueAsync = ref.watch(historiquePrestationProvider(prestationId));
    final droits = ref.watch(droitsServicesProvider);
    final documents = ref.watch(documentsProvider).value ?? const <Document>[];
    final facture = documents.where((d) => d.origineId == prestationId && d.type == TypeDocument.facture && !d.refuse).firstOrNull;
    final droitsDocs = ref.watch(droitsDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          prestationsAsync.value?.where((x) => x.id == prestationId).firstOrNull?.estContrat == true
              ? 'Contrat de service'
              : 'Rapport d\'intervention',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'Bon de prise en charge',
            onPressed: () {
              final p = prestationsAsync.value?.where((x) => x.id == prestationId).firstOrNull;
              if (p != null) BonPriseEnChargeDialog.afficher(context, p);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => context.push('/services/prestations/$prestationId/edit'),
          ),
          const SyncStatusButton(),
        ],
      ),
      body: AsyncValueView<List<Prestation>>(
        value: prestationsAsync,
        onRetry: () => ref.invalidate(prestationsProvider),
        data: (prestations) {
          final prestation = prestations.where((p) => p.id == prestationId).firstOrNull;
          if (prestation == null) {
            return const Center(child: Text('Prestation introuvable'));
          }

          final contact = prestation.contactId != null
              ? ref.watch(contactProvider(prestation.contactId!)).value
              : null;

          final metierTemplate = MetierTemplate.templatePour(prestation.metierCode);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. En-tête Titre, Montant et Badges
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        prestation.estContrat ? Icons.assignment_outlined : Icons.handyman_rounded,
                                        size: 16,
                                        color: prestation.estContrat ? const Color(0xFF01226C) : const Color(0xFF0284C7),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          prestation.estContrat
                                              ? 'CONTRAT DE SERVICE${prestation.metierCode != MetierCode.generique ? ' • ${metierTemplate.code.libelle.toUpperCase()}' : ''}'
                                              : 'INTERVENTION TERRAIN',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                            color: prestation.estContrat ? const Color(0xFF01226C) : const Color(0xFF0284C7),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    prestation.titre,
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.ink),
                                  ),
                                  if (prestation.description != null && prestation.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        prestation.description!,
                                        style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  montant(context, ref, prestation.total),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20,
                                    color: Color(0xFF01226C),
                                  ),
                                ),
                                if (prestation.remise > 0)
                                  Text(
                                    'Remise : ${montant(context, ref, prestation.remise)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatutPrestationBadge(statut: prestation.statut),
                            StatutFinancierBadge(prestation: prestation),
                            PrioriteEcheanceBadge(prestation: prestation, compact: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Boutons d'Action Métier (Avancement du travail)
                  if (prestation.statut != StatutPrestation.annulee)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Actions d\'intervention', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (droits.peutModifierPrestations &&
                                  (prestation.statut == StatutPrestation.aFaire || prestation.statut == StatutPrestation.planifiee))
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Démarrer'),
                                  onPressed: () => _changerStatut(context, ref, prestation, StatutPrestation.enCours),
                                ),
                              if (droits.peutModifierPrestations && prestation.statut == StatutPrestation.enCours)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.green, minimumSize: const Size(0, 40)),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Terminer le travail'),
                                  onPressed: () => _changerStatut(context, ref, prestation, StatutPrestation.terminee),
                                ),
                              if (droits.peutModifierPrestations &&
                                  (prestation.statut == StatutPrestation.terminee))
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), minimumSize: const Size(0, 40)),
                                  icon: const Icon(Icons.handshake_outlined, size: 18),
                                  label: const Text('Remettre au client'),
                                  onPressed: () => _changerStatut(context, ref, prestation, StatutPrestation.livree),
                                ),
                              if (facture != null)
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.receipt_long, size: 18),
                                  label: Text('Facture ${facture.numero}'),
                                  onPressed: () => context.push(Routes.document(facture.id)),
                                )
                              else if (droitsDocs.creer)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                  label: const Text('Émettre la facture'),
                                  onPressed: () => _emettreFacture(context, ref, prestation),
                                ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                                label: const Text('Bon de prise en charge'),
                                onPressed: () => BonPriseEnChargeDialog.afficher(context, prestation),
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                                label: const Text('Rappeler le client'),
                                onPressed: () => PrestationRappelDialog.afficher(context, prestation),
                              ),
                              if (droits.peutModifierPrestations)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.event_repeat_rounded, size: 18),
                                  label: const Text('Reporter échéance'),
                                  onPressed: () => _reporterDialogue(context, ref, prestation),
                                ),
                              if (droits.peutAnnulerPrestations)
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.negative),
                                  label: const Text('Annuler', style: TextStyle(color: AppColors.negative)),
                                  onPressed: () => _annulerDialogue(context, ref, prestation),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 3. Spécifications & Caractéristiques Métier (si configurées)
                  if (prestation.champsMetier.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(metierTemplate.code.icone, size: 18, color: const Color(0xFF01226C)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Détails du dossier — ${metierTemplate.code.libelle}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              for (final entry in prestation.champsMetier.entries)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        entry.key.replaceAll('_', ' ').toUpperCase(),
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${entry.value}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (prestation.champsMetier.isNotEmpty) const SizedBox(height: 16),

                  // 4. Photographies du Dossier (Capture, Galerie, Catégories)
                  PrestationPhotosSection(
                    photos: prestation.photos,
                    prestationId: prestation.id,
                    onPhotosChanged: (photos) async {
                      final maj = prestation.copyWith(photos: photos);
                      await ref.read(servicesRepositoryProvider).modifierPrestation(maj);
                      ref.invalidate(prestationsProvider);
                      ref.invalidate(prestationDetailProvider(prestation.id));
                    },
                  ),
                  const SizedBox(height: 16),

                  // 5. Suivi Financier & Encaissements
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('Règlement & Caisse', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            ),
                            if (prestation.soldeRestant > 0)
                              FilledButton.tonalIcon(
                                style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                                icon: const Icon(Icons.payments_outlined, size: 18),
                                label: const Text('Encaisser'),
                                onPressed: () => context.push(Routes.paiementNouveau(engagementId: prestation.id)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _SyntheseFinanciereBoite(
                                titre: 'Total facturé',
                                valeur: montant(context, ref, prestation.total),
                                couleur: const Color(0xFF01226C),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SyntheseFinanciereBoite(
                                titre: 'Déjà réglé',
                                valeur: montant(context, ref, prestation.montantRegle),
                                couleur: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _SyntheseFinanciereBoite(
                                titre: 'Solde restant',
                                valeur: montant(context, ref, prestation.soldeRestant),
                                couleur: prestation.soldeRestant > 0 ? AppColors.negative : AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Lignes de Prestations
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Détail des prestations', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 10),
                        for (final l in prestation.lignes)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(l.libelle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                          ),
                                          if (l.estConsommable) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('📦 Pièce stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text('${l.quantite} × ${montant(context, ref, l.prixUnitaire)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                Text(
                                  montant(context, ref, l.totalLigne),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 7. Informations Client & Échéances
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prestation.estContrat ? 'Durée & Engagement contractuel' : 'Planification & Intervention',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        if (contact != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(child: Icon(Icons.person, size: 20)),
                            title: Text(contact.nomAffiche, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text(contact.telephone ?? 'Sans numéro de téléphone'),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            onTap: () => context.push(Routes.contact(contact.id)),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Text('Client comptoir / Non renseigné', style: TextStyle(color: AppColors.muted)),
                          ),
                        const Divider(height: 16),
                        if (prestation.estContrat && prestation.debutPrevu != null && prestation.echeanceJour != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.date_range_rounded, size: 16, color: Color(0xFF01226C)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Période : Du ${DateFormat('dd/MM/yyyy').format(prestation.debutPrevu!)} au ${DateFormat('dd/MM/yyyy').format(prestation.echeanceJour!)}'
                                  '${prestation.dureeEstimee != null ? ' (${prestation.dureeEstimee} ${prestation.uniteDuree.name})' : ''}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF01226C)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ] else ...[
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  prestation.echeanceJour != null
                                      ? 'Date prévue : ${DateFormat('dd/MM/yyyy').format(prestation.echeanceJour!)}${prestation.echeanceHeure != null ? ' à ${prestation.echeanceHeure}' : ''}${prestation.dureeMinutes != null ? ' (${prestation.dureeMinutes} min)' : ''}'
                                      : 'Sans date limite spécifiée',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (prestation.dateTerminaisonReelle != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.task_alt_rounded, size: 16, color: AppColors.green),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Travail terminé le : ${DateFormat('dd/MM/yyyy à HH:mm').format(prestation.dateTerminaisonReelle!)}',
                                  style: const TextStyle(fontSize: 13, color: AppColors.green, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (prestation.dateRemiseReelle != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.handshake_outlined, size: 16, color: Color(0xFF7C3AED)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Remis au client le : ${DateFormat('dd/MM/yyyy à HH:mm').format(prestation.dateRemiseReelle!)}',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (prestation.lieu != null && prestation.lieu!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text('Lieu : ${prestation.lieu}', style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 8. Historique des Modifications
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Historique & Traçabilité', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 10),
                        historiqueAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (e, stack) => const Text('Historique indisponible'),
                          data: (historique) {
                            if (historique.isEmpty) {
                              return const Text('Aucune modification enregistrée', style: TextStyle(color: AppColors.muted, fontSize: 12.5));
                            }
                            return Column(
                              children: [
                                for (final h in historique)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.circle, size: 8, color: Color(0xFF01226C)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${h.type} : ${h.nouveau ?? ""}${h.motif != null ? " (${h.motif})" : ""}',
                                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          DateFormat('dd/MM HH:mm').format(h.createdAt),
                                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _changerStatut(BuildContext context, WidgetRef ref, Prestation p, StatutPrestation nouveau) async {
    try {
      final now = DateTime.now();
      DateTime? termineLe = p.termineLe;
      DateTime? termineReel = p.dateTerminaisonReelle;
      DateTime? livreLe = p.livreLe;
      DateTime? remiseReelle = p.dateRemiseReelle;

      if (nouveau == StatutPrestation.terminee) {
        termineLe = now;
        termineReel = now;
      } else if (nouveau == StatutPrestation.livree) {
        livreLe = now;
        remiseReelle = now;
      }

      final maj = p.copyWith(
        statut: nouveau,
        termineLe: termineLe,
        dateTerminaisonReelle: termineReel,
        livreLe: livreLe,
        dateRemiseReelle: remiseReelle,
      );

      await ref.read(gererServicesProvider).modifierPrestation(maj);
      ref.invalidate(prestationDetailProvider(p.id));
      ref.invalidate(prestationsProvider);
    } catch (e) {
      if (context.mounted) showFailureSnackBar(context, e);
    }
  }

  Future<void> _reporterDialogue(BuildContext context, WidgetRef ref, Prestation p) async {
    DateTime nouvelleDate = p.echeanceJour ?? DateTime.now().add(const Duration(days: 1));
    final motifCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Reporter la prestation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: Text(DateFormat('dd/MM/yyyy').format(nouvelleDate)),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: nouvelleDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (d != null) setDlgState(() => nouvelleDate = d);
                },
              ),
              TextField(
                controller: motifCtrl,
                decoration: const InputDecoration(labelText: 'Motif du report *', hintText: 'Ex. Pièce en attente, demande client...'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dlgCtx).pop(), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                if (motifCtrl.text.trim().isEmpty) return;
                try {
                  await ref.read(gererServicesProvider).reporterPrestation(
                        prestationId: p.id,
                        nouvelleEcheanceJour: nouvelleDate,
                        motif: motifCtrl.text.trim(),
                      );
                  ref.invalidate(prestationDetailProvider(p.id));
                  ref.invalidate(prestationsProvider);
                  if (context.mounted) Navigator.of(dlgCtx).pop();
                } catch (e) {
                  if (context.mounted) showFailureSnackBar(context, e);
                }
              },
              child: const Text('Valider le report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _annulerDialogue(BuildContext context, WidgetRef ref, Prestation p) async {
    final motifCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Text('Annuler la prestation'),
        content: TextField(
          controller: motifCtrl,
          decoration: const InputDecoration(labelText: 'Motif d\'annulation *', hintText: 'Ex. Abandon client, impossibilité technique...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dlgCtx).pop(), child: const Text('Fermer')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
            onPressed: () async {
              if (motifCtrl.text.trim().isEmpty) return;
              try {
                await ref.read(gererServicesProvider).annulerPrestation(
                      prestationId: p.id,
                      motif: motifCtrl.text.trim(),
                    );
                ref.invalidate(prestationDetailProvider(p.id));
                ref.invalidate(prestationsProvider);
                if (context.mounted) Navigator.of(dlgCtx).pop();
              } catch (e) {
                if (context.mounted) showFailureSnackBar(context, e);
              }
            },
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }

  Future<void> _emettreFacture(BuildContext context, WidgetRef ref, Prestation prestation) async {
    final ctx = ref.read(contexteActifProvider);
    if (ctx == null) return;
    final profil = await ref.read(profilEntrepriseProvider.future).catchError((_) => null);
    final contact = prestation.contactId != null ? ref.read(contactProvider(prestation.contactId!)).value : null;
    final appareilId = ref.read(appareilIdProvider);

    try {
      final doc = await ref.read(emettreDocumentProvider).call(
            ctx,
            type: TypeDocument.facture,
            origineType: 'PRESTATION',
            origineId: prestation.id,
            contactId: prestation.contactId,
            perimetreId: prestation.perimetreId,
            montant: prestation.total,
            appareilId: appareilId,
            contenu: {
              'entreprise': {
                'nom': profil?.nom ?? ctx.entreprise!.nom,
                'telephone': profil?.telephone,
                'adresse': profil?.adresse,
                'ville': profil?.ville,
                'identifiant_fiscal': profil?.identifiantFiscal,
                'registre_commerce': profil?.registreCommerce,
                'devise': profil?.devise ?? ctx.entreprise!.devise ?? 'XOF',
              },
              'contact': contact == null
                  ? null
                  : {
                      'nom': contact.nomAffiche,
                      'telephone': contact.telephone,
                      'email': contact.email,
                      'adresse': contact.adresse,
                    },
              'titre': prestation.titre,
              'description': prestation.description,
              'reference_metier': prestation.champsMetier['numero_dossier'] ?? prestation.champsMetier['immatriculation'],
              'date_echeance': prestation.echeanceJour?.toUtc().toIso8601String(),
              'lignes': [
                for (final l in prestation.lignes)
                  {
                    'libelle': l.libelle,
                    'quantite': l.quantite,
                    'prix_unitaire': l.prixUnitaire,
                    'montant': (l.quantite * l.prixUnitaire).round(),
                  }
              ],
              'remise': prestation.remise,
              'sous_total': prestation.lignes.fold<int>(0, (sum, l) => sum + (l.quantite * l.prixUnitaire).round()),
              'paye': prestation.montantRegle,
              'reste': prestation.soldeRestant,
              'pied': profil?.piedRecu,
            },
          );
      if (context.mounted) {
        context.push(Routes.document(doc.id));
      }
    } catch (e) {
      if (context.mounted) {
        showFailureSnackBar(context, e);
      }
    }
  }
}

class _SyntheseFinanciereBoite extends StatelessWidget {
  const _SyntheseFinanciereBoite({required this.titre, required this.valeur, required this.couleur});
  final String titre;
  final String valeur;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: couleur),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valeur,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}
