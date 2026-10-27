import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/contrat_widgets.dart';
import '../widgets/immobilier_widgets.dart';

class ContratDetailsPage extends ConsumerWidget {
  const ContratDetailsPage({super.key, required this.contratId});
  final String contratId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contratAsync = ref.watch(contratDetailsProvider(contratId));
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Contrat de Bail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Modifier',
            onPressed: () => context.push(Routes.contratModifier(contratId)),
          ),
        ],
      ),
      body: contratAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(contratDetailsProvider(contratId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (contrat) {
          if (contrat == null) {
            // Fallback: search in list
            final tous = ref.watch(contratsListProvider).value ?? const [];
            final trouve = tous.where((c) => c.id == contratId).firstOrNull;
            if (trouve == null) {
              return const MessageView(
                icon: Icons.history_edu_outlined,
                title: 'Contrat introuvable',
                message: 'Ce contrat de bail n\'existe pas ou a été supprimé.',
              );
            }
            return _buildContratBody(context, ref, trouve, devise, l10n);
          }
          return _buildContratBody(context, ref, contrat, devise, l10n);
        },
      ),
    );
  }

  Widget _buildContratBody(
    BuildContext context,
    WidgetRef ref,
    ContratBail contrat,
    String devise,
    AppLocalizations l10n,
  ) {
    final bien = ref.watch(bienDetailsProvider(contrat.bienId)).value;
    final locataire = ref.watch(contactProvider(contrat.locataireId)).value;
    final proprietaire = ref.watch(contactProvider(contrat.proprietaireId)).value;

    final dateDebutFormat =
        '${contrat.dateDebut.day.toString().padLeft(2, '0')}/${contrat.dateDebut.month.toString().padLeft(2, '0')}/${contrat.dateDebut.year}';
    final dateFinFormat = contrat.dateFinPrevue != null
        ? '${contrat.dateFinPrevue!.day.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.month.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.year}'
        : 'Indéterminée';
    final dateSignFormat = contrat.dateSignature != null
        ? '${contrat.dateSignature!.day.toString().padLeft(2, '0')}/${contrat.dateSignature!.month.toString().padLeft(2, '0')}/${contrat.dateSignature!.year}'
        : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Synthèse statut, référence et loyer
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatutContratBadge(statut: contrat.statut),
                    Text(
                      '${l10n.montant(contrat.totalMensuel, devise)} / mois',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contrat.reference,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          TypeBailBadge(type: contrat.typeBail),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 16, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Text(
                          '$dateDebutFormat → $dateFinFormat',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    SignatureStatutIndicator(
                      signeBailleur: contrat.signeParBailleur,
                      signeLocataire: contrat.signeParLocataire,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.09),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: const Text(
                      'Visualiser l\'acte officiel de bail complet',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    onPressed: () => _afficherContratCompletModal(
                      context,
                      contrat,
                      bien,
                      locataire,
                      proprietaire,
                      devise,
                      l10n,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_card_rounded, size: 18),
                    label: const Text(
                      'Recevoir un loyer pour ce bail',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    onPressed: () => context.push(
                      Routes.loyerRecevoirAvec(bienId: contrat.bienId, locataireId: contrat.locataireId),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. LE LOGEMENT LOUÉ
        const Text(
          'LOGEMENT LOUÉ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    bien?.type.icone ?? Icons.home_work_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  bien?.nom ?? 'Bien (#${contrat.bienId.substring(0, 6)})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                subtitle: Text(
                  bien != null
                      ? '${bien.adresseComplete}${bien.caracteristiques.surfaceM2 != null ? ' · ${bien.caracteristiques.surfaceM2} m²' : ''}'
                      : 'Identifiant : ${contrat.bienId}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: bien != null ? StatutBienBadge(statut: bien.statut) : null,
                onTap: () => context.push(Routes.bienDetails(contrat.bienId)),
              ),
              if (bien != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (bien.caracteristiques.surfaceM2 != null)
                        _TagCarac(icone: Icons.straighten_rounded, label: '${bien.caracteristiques.surfaceM2} m²'),
                      if (bien.caracteristiques.nbPieces != null)
                        _TagCarac(icone: Icons.meeting_room_outlined, label: '${bien.caracteristiques.nbPieces} pièces'),
                      if (bien.caracteristiques.nbChambres != null)
                        _TagCarac(icone: Icons.bed_outlined, label: '${bien.caracteristiques.nbChambres} ch.'),
                      if (bien.caracteristiques.etage != null)
                        _TagCarac(icone: Icons.layers_outlined, label: 'Étage ${bien.caracteristiques.etage}'),
                      if (bien.caracteristiques.meuble)
                        const _TagCarac(icone: Icons.chair_outlined, label: 'Meublé'),
                      if (bien.caracteristiques.climatisation)
                        const _TagCarac(icone: Icons.ac_unit_rounded, label: 'Climatisé'),
                      if (bien.caracteristiques.parking)
                        const _TagCarac(icone: Icons.directions_car_outlined, label: 'Parking'),
                      if (bien.caracteristiques.compteurEauIndependant)
                        const _TagCarac(icone: Icons.water_drop_outlined, label: 'Compteur eau dédié'),
                      if (bien.caracteristiques.compteurElectriciteIndependant)
                        const _TagCarac(icone: Icons.electric_bolt_outlined, label: 'Compteur élec dédié'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 3. LOCATAIRE ET BAILLEUR
        const Text(
          'PARTIES PRENANTES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Column(
            children: [
              ListTile(
                leading: locataire != null
                    ? ContactAvatar(contact: locataire, radius: 20)
                    : const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                title: Text(
                  locataire?.nomAffiche ?? 'Locataire (#${contrat.locataireId.substring(0, 6)})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  'Locataire occupant (Preneur) · ${locataire?.telephone ?? 'Pas de numéro'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: () => context.push(Routes.locataireDetails(contrat.locataireId)),
              ),
              const Divider(height: 1, indent: 64, color: AppColors.border),
              ListTile(
                leading: proprietaire != null
                    ? ContactAvatar(contact: proprietaire, radius: 20)
                    : const CircleAvatar(radius: 20, child: Icon(Icons.badge_outlined)),
                title: Text(
                  proprietaire?.nomAffiche ?? 'Propriétaire (#${contrat.proprietaireId.substring(0, 6)})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                subtitle: Text(
                  'Bailleur légal (Propriétaire) · ${proprietaire?.telephone ?? 'Pas de numéro'}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: () => context.push(Routes.proprietaireDetails(contrat.proprietaireId)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. MODALITÉS FINANCIÈRES & DURÉE
        const Text(
          'CONDITIONS FINANCIÈRES & DURÉE DU BAIL',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildLigneFinanciere(
                  'Loyer mensuel net',
                  '${l10n.montant(contrat.loyerMensuel, devise)} / mois',
                  Icons.payments_outlined,
                  AppColors.primary,
                ),
                const SizedBox(height: 8),
                _buildLigneFinanciere(
                  'Charges mensuelles',
                  '${l10n.montant(contrat.chargesMensuelles, devise)} / mois',
                  Icons.water_drop_outlined,
                  AppColors.muted,
                ),
                const Divider(height: 16, color: AppColors.border),
                _buildLigneFinanciere(
                  'Total exigible par mois',
                  '${l10n.montant(contrat.totalMensuel, devise)} / mois',
                  Icons.account_balance_wallet_outlined,
                  AppColors.primary,
                  isBold: true,
                ),
                const Divider(height: 16, color: AppColors.border),
                _buildLigneFinanciere(
                  'Dépôt de garantie (Caution)',
                  contrat.depotGarantie > 0 ? l10n.montant(contrat.depotGarantie, devise) : 'Néant / Non exigé',
                  Icons.savings_outlined,
                  const Color(0xFFDF9540),
                  isBold: true,
                ),
                const SizedBox(height: 8),
                _buildLigneFinanciere(
                  'Reconduction tacite',
                  contrat.reconductionTacite ? 'Oui (Renouvellement automatique)' : 'Non (Prend fin au terme)',
                  Icons.autorenew_rounded,
                  AppColors.ink,
                ),
                const SizedBox(height: 8),
                _buildLigneFinanciere(
                  'Délai de préavis de congé',
                  '${contrat.preavisMois} mois',
                  Icons.notifications_active_outlined,
                  AppColors.ink,
                ),
                if (contrat.penaliteRetardPourcent != null && contrat.penaliteRetardPourcent! > 0) ...[
                  const SizedBox(height: 8),
                  _buildLigneFinanciere(
                    'Pénalité de retard',
                    '${contrat.penaliteRetardPourcent}% par période',
                    Icons.warning_amber_rounded,
                    const Color(0xFFDF9540),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Paiement exigible avant le ${contrat.termePaiementJour} du mois (${contrat.termeType == TermePaiementType.aEchoir ? 'Terme à échoir - d\'avance' : 'Terme échu - à terme'})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 5. ARTICLES & CONTENU DU CONTRAT DE BAIL
        const Text(
          'CONTENU & STIPULATIONS DU CONTRAT',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildArticleTile(
                  numero: '1',
                  titre: 'Objet & Désignation des lieux',
                  contenu:
                      'Le Bailleur loue au Preneur qui l\'accepte le bien immobilier ci-après désigné : ${bien?.nom ?? 'Bien sous référence ${contrat.bienId}'}, sis à ${bien?.adresseComplete ?? 'Adresse indiquée aux présentes'}, de catégorie "${contrat.typeBail.libelle}". Le Preneur déclare parfaitement connaître les lieux pour les avoir visités.',
                ),
                _buildArticleTile(
                  numero: '2',
                  titre: 'Destination des lieux loués',
                  contenu:
                      'Les locaux faisant l\'objet du présent contrat sont exclusivement destinés à un usage ${contrat.typeBail == TypeBail.commercial ? 'commercial' : contrat.typeBail == TypeBail.professionnel ? 'professionnel' : 'd\'habitation principale'}. Toute modification de cette affectation sans accord écrit préalable du bailleur est formellement prohibée.',
                ),
                _buildArticleTile(
                  numero: '3',
                  titre: 'Durée du bail & Modalités de congé',
                  contenu:
                      'Le bail prend effet le $dateDebutFormat pour s\'achever le $dateFinFormat. ${contrat.reconductionTacite ? 'À son échéance, il se renouvellera par tacite reconduction aux mêmes conditions.' : 'Il prendra fin de plein droit sans préavis à la date prévue.'} Chaque partie peut y mettre fin moyennant un préavis obligatoire de ${contrat.preavisMois} mois formulé par écrit.',
                ),
                _buildArticleTile(
                  numero: '4',
                  titre: 'Loyer, charges & Modalités de règlement',
                  contenu:
                      'Le présent bail est consenti et accepté moyennant un loyer mensuel net de ${l10n.montant(contrat.loyerMensuel, devise)}, majoré d\'une provision pour charges de ${l10n.montant(contrat.chargesMensuelles, devise)}, soit un total mensuel exigible de ${l10n.montant(contrat.totalMensuel, devise)}. Le paiement s\'effectue au plus tard le ${contrat.termePaiementJour} de chaque mois (${contrat.termeType == TermePaiementType.aEchoir ? 'terme à échoir' : 'terme échu'}).',
                ),
                _buildArticleTile(
                  numero: '5',
                  titre: 'Dépôt de garantie & Cautionnement',
                  contenu:
                      contrat.depotGarantie > 0
                          ? 'À la signature des présentes, le Preneur verse la somme de ${l10n.montant(contrat.depotGarantie, devise)} à titre de dépôt de garantie non productif d\'intérêts. Il sera restitué en fin de bail après remise des clés et état des lieux de sortie contradictoire, déduction faite de toute somme restant due.'
                          : 'Aucun dépôt de garantie financier n\'a été consigné pour ce contrat.',
                ),
                if (contrat.penaliteRetardPourcent != null && contrat.penaliteRetardPourcent! > 0)
                  _buildArticleTile(
                    numero: '6',
                    titre: 'Pénalités de retard',
                    contenu:
                        'À défaut de paiement du terme dans un délai de 8 jours suivant son exigibilité, le montant dû sera automatiquement majoré de plein droit d\'une pénalité de retard de ${contrat.penaliteRetardPourcent}%.',
                  ),
                _buildArticleTile(
                  numero: contrat.penaliteRetardPourcent != null ? '7' : '6',
                  titre: 'Obligations essentielles du Preneur',
                  contenu:
                      'Le Preneur s\'engage à : 1° Payer exactement le loyer et charges aux termes convenus. 2° Occuper paisiblement les lieux en bon père de famille. 3° Ne pas sous-louer ni céder ses droits sans agrément écrit du Bailleur. 4° Prendre à sa charge l\'entretien courant et les menues réparations locatives.',
                ),
                _buildArticleTile(
                  numero: contrat.penaliteRetardPourcent != null ? '8' : '7',
                  titre: 'Obligations du Bailleur',
                  contenu:
                      'Le Bailleur s\'oblige à : 1° Mettre à disposition du Preneur des locaux décents, en bon état d\'usage et de fonctionnement. 2° Assurer au Preneur une jouissance paisible des lieux loués. 3° Prendre en charge les grosses réparations structurelles définies par la loi.',
                ),
                if (contrat.clausesParticulieres != null && contrat.clausesParticulieres!.trim().isNotEmpty)
                  _buildArticleTile(
                    numero: contrat.penaliteRetardPourcent != null ? '9' : '8',
                    titre: 'Clauses particulières & Stipulations dérogatoires',
                    contenu: contrat.clausesParticulieres!.trim(),
                    estMiseEnValeur: true,
                  ),
                _buildArticleTile(
                  numero: contrat.clausesParticulieres != null && contrat.clausesParticulieres!.trim().isNotEmpty
                      ? (contrat.penaliteRetardPourcent != null ? '10' : '9')
                      : (contrat.penaliteRetardPourcent != null ? '9' : '8'),
                  titre: 'Clause résolutoire & Juridiction',
                  contenu:
                      'Il est expressément convenu qu\'à défaut de paiement d\'un seul terme de loyer ou en cas d\'inexécution d\'une des clauses du présent bail, le contrat sera résilié immédiatement de plein droit. Tout litige relèvera de la juridiction territorialement compétente du lieu de situation de l\'immeuble.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 6. SIGNATURES & VALIDATION JURIDIQUE
        const Text(
          'STATUT DES SIGNATURES',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      contrat.signeParBailleur ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: contrat.signeParBailleur ? const Color(0xFF10B981) : AppColors.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Signature du Bailleur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (!contrat.signeParBailleur)
                      TextButton.icon(
                        icon: const Icon(Icons.draw_rounded, size: 15),
                        label: const Text('Signer'),
                        onPressed: () => _signer(ref, contrat, bailleur: true),
                      )
                    else
                      const Text('Signé', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const Divider(height: 12, color: AppColors.border),
                Row(
                  children: [
                    Icon(
                      contrat.signeParLocataire ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: contrat.signeParLocataire ? const Color(0xFF10B981) : AppColors.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Signature du Locataire', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    if (!contrat.signeParLocataire)
                      TextButton.icon(
                        icon: const Icon(Icons.draw_rounded, size: 15),
                        label: const Text('Signer'),
                        onPressed: () => _signer(ref, contrat, locataire: true),
                      )
                    else
                      const Text('Signé', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                if (dateSignFormat != null) ...[
                  const Divider(height: 12, color: AppColors.border),
                  Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 15, color: AppColors.muted),
                      const SizedBox(width: 8),
                      Text(
                        'Date de signature : $dateSignFormat',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 7. ACTIONS SUR LE STATUT
        const Text(
          'CYCLE DE VIE DU BAIL',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (contrat.statut == StatutContratBail.brouillon)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: const Text('Activer le contrat'),
                onPressed: () => _changerStatut(ref, contrat, StatutContratBail.actif),
              ),
            if (contrat.statut == StatutContratBail.actif)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFDF9540)),
                icon: const Icon(Icons.notification_important_outlined, size: 18),
                label: const Text('Poser un préavis de congé'),
                onPressed: () => _changerStatut(ref, contrat, StatutContratBail.enPreavis),
              ),
            if (contrat.statut == StatutContratBail.enPreavis || contrat.statut == StatutContratBail.actif)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
                icon: const Icon(Icons.event_available_rounded, size: 18),
                label: const Text('Terminer à échéance'),
                onPressed: () => _changerStatut(ref, contrat, StatutContratBail.termine),
              ),
            if (contrat.statut != StatutContratBail.resilie && contrat.statut != StatutContratBail.termine)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Résilier le contrat'),
                onPressed: () => _changerStatut(ref, contrat, StatutContratBail.resilie),
              ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildArticleTile({
    required String numero,
    required String titre,
    required String contenu,
    bool estMiseEnValeur = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: estMiseEnValeur ? AppColors.primary.withValues(alpha: 0.05) : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: estMiseEnValeur ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Art. $numero',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              contenu,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLigneFinanciere(
    String titre,
    String montant,
    IconData icone,
    Color couleur, {
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icone, size: 17, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            titre,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
              color: isBold ? AppColors.ink : AppColors.muted,
            ),
          ),
        ),
        Text(
          montant,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: couleur,
          ),
        ),
      ],
    );
  }

  void _afficherContratCompletModal(
    BuildContext context,
    ContratBail contrat,
    BienImmobilier? bien,
    Contact? locataire,
    Contact? proprietaire,
    String devise,
    AppLocalizations l10n,
  ) {
    final dateDebutFormat =
        '${contrat.dateDebut.day.toString().padLeft(2, '0')}/${contrat.dateDebut.month.toString().padLeft(2, '0')}/${contrat.dateDebut.year}';
    final dateFinFormat = contrat.dateFinPrevue != null
        ? '${contrat.dateFinPrevue!.day.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.month.toString().padLeft(2, '0')}/${contrat.dateFinPrevue!.year}'
        : 'Indéterminée';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Barre de glissement
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // En-tête du modal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ACTE DE CONTRAT DE BAIL',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary),
                            ),
                            Text(
                              'Réf : ${contrat.reference} · ${contrat.typeBail.libelle}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                              tooltip: 'Copier le texte du contrat',
                              onPressed: () {
                                final texte = _genererTexteContrat(
                                  contrat,
                                  bien,
                                  locataire,
                                  proprietaire,
                                  dateDebutFormat,
                                  dateFinFormat,
                                  devise,
                                  l10n,
                                );
                                Clipboard.setData(ClipboardData(text: texte));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Texte intégral du contrat copié dans le presse-papiers.'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.border),
                  // Contenu du document
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(20),
                      children: [
                        // En-tête style document officiel
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.primary.withValues(alpha: 0.03),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.gavel_rounded, color: AppColors.primary, size: 28),
                              const SizedBox(height: 6),
                              Text(
                                'CONTRAT DE LOCATION / BAIL ${contrat.typeBail.libelle.toUpperCase()}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.ink),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Sous seing privé · Réf : ${contrat.reference}',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section Parties prenantes
                        const Text(
                          'ENTRE LES SOUSSIGNÉS :',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                        ),
                        const SizedBox(height: 6),
                        _buildFichePartie(
                          titre: '1. LE BAILLEUR (Propriétaire) :',
                          nom: proprietaire?.nomAffiche ?? 'Non spécifié',
                          telephone: proprietaire?.telephone,
                          adresse: proprietaire?.adresse ?? proprietaire?.ville,
                        ),
                        const SizedBox(height: 10),
                        _buildFichePartie(
                          titre: '2. LE PRENEUR (Locataire) :',
                          nom: locataire?.nomAffiche ?? 'Non spécifié',
                          telephone: locataire?.telephone,
                          adresse: locataire?.adresse ?? locataire?.ville,
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'IL A ÉTÉ CONVENU ET ARRÊTÉ CE QUI SUIT :',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                        ),
                        const SizedBox(height: 10),

                        _buildArticlePaper(
                          'ARTICLE 1 — OBJET ET DÉSIGNATION DES LIEUX LOUÉS',
                          'Le Bailleur donne à bail au Preneur qui accepte les locaux ci-après désignés :\n'
                          '• Bien : ${bien?.nom ?? 'Non précisé'}\n'
                          '• Adresse : ${bien?.adresseComplete.isNotEmpty == true ? bien!.adresseComplete : 'Adresse non renseignée'}\n'
                          '• Type : ${bien?.type.libelle ?? contrat.typeBail.libelle}\n'
                          '${bien?.caracteristiques.surfaceM2 != null ? '• Surface : ${bien!.caracteristiques.surfaceM2} m²\n' : ''}'
                          '${bien?.caracteristiques.nbPieces != null ? '• Nombre de pièces : ${bien!.caracteristiques.nbPieces}\n' : ''}'
                          'Le Preneur déclare avoir visité les lieux et les trouver en bon état.',
                        ),

                        _buildArticlePaper(
                          'ARTICLE 2 — DESTINATION DES LIEUX',
                          'Les locaux loués sont exclusivement destinés à l\'usage de "${contrat.typeBail.libelle}". Le Preneur s\'interdit formellement d\'y exercer une autre activité sans l\'accord écrit et préalable du Bailleur.',
                        ),

                        _buildArticlePaper(
                          'ARTICLE 3 — DURÉE DU BAIL ET CONGÉ',
                          'Le présent contrat est conclu pour une durée déterminée prenant effet le $dateDebutFormat et expirant le $dateFinFormat.\n'
                          '${contrat.reconductionTacite ? 'À son terme, il sera renouvelé par tacite reconduction pour une durée identique.' : 'Le bail prend fin de plein droit sans préavis au terme fixé.'}\n'
                          'Chacune des parties a la faculté de résilier le bail en observant un préavis d\'au moins ${contrat.preavisMois} mois notifié par tout moyen laissant trace écrite.',
                        ),

                        _buildArticlePaper(
                          'ARTICLE 4 — CONDITIONS FINANCIÈRES (LOYER ET CHARGES)',
                          'Le présent bail est consenti et accepté moyennant les conditions financières suivantes :\n'
                          '• Loyer mensuel principal net : ${l10n.montant(contrat.loyerMensuel, devise)}\n'
                          '• Provision mensuelle pour charges : ${l10n.montant(contrat.chargesMensuelles, devise)}\n'
                          '• Montant total mensuel exigible : ${l10n.montant(contrat.totalMensuel, devise)}\n'
                          'Le loyer est payable d\'avance au plus tard le ${contrat.termePaiementJour} de chaque mois (${contrat.termeType == TermePaiementType.aEchoir ? 'Terme à échoir' : 'Terme échu'}).',
                        ),

                        _buildArticlePaper(
                          'ARTICLE 5 — DÉPÔT DE GARANTIE',
                          contrat.depotGarantie > 0
                              ? 'Le Preneur verse ce jour au Bailleur la somme de ${l10n.montant(contrat.depotGarantie, devise)} à titre de dépôt de garantie. Ce dépôt garantit la bonne exécution des obligations locatives et sera restitué dans un délai maximum de 2 mois suivant la restitution des clés, déduction faite de toute somme restant due.'
                              : 'Aucun dépôt de garantie n\'a été consigné lors de la signature du présent bail.',
                        ),

                        if (contrat.penaliteRetardPourcent != null && contrat.penaliteRetardPourcent! > 0)
                          _buildArticlePaper(
                            'ARTICLE 6 — PÉNALITÉ DE RETARD',
                            'En cas de retard de paiement supérieur à 8 jours après l\'échéance, les sommes dues porteront intérêt et seront majorées d\'une pénalité contractuelle de ${contrat.penaliteRetardPourcent}%.',
                          ),

                        _buildArticlePaper(
                          'ARTICLE ${contrat.penaliteRetardPourcent != null ? '7' : '6'} — OBLIGATIONS DES PARTIES',
                          '1° Le Preneur s\'engage à payer ponctuellement le loyer et charges, user paisiblement des locaux et répondre des dégradations commises.\n'
                          '2° La sous-location ou cession de bail est formellement interdite sans l\'accord écrit du Bailleur.\n'
                          '3° Le Bailleur s\'engage à délivrer un logement décent et en bon état, et à assurer les grosses réparations lui incombant légalement.',
                        ),

                        if (contrat.clausesParticulieres != null && contrat.clausesParticulieres!.trim().isNotEmpty)
                          _buildArticlePaper(
                            'ARTICLE ${contrat.penaliteRetardPourcent != null ? '8' : '7'} — CLAUSES & CONDITIONS PARTICULIÈRES',
                            contrat.clausesParticulieres!.trim(),
                          ),

                        _buildArticlePaper(
                          'ARTICLE FINAL — CLAUSE RÉSOLUTOIRE ET LITIGES',
                          'À défaut de paiement d\'un seul terme ou d\'inexécution d\'une seule clause, le présent bail sera résilié de plein droit après mise en demeure restée infructueuse. En cas de contestation, attribution de compétence est faite aux tribunaux compétents du lieu de situation de l\'immeuble.',
                        ),

                        const SizedBox(height: 16),
                        // Zone des signatures
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.background,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fait à ${bien?.ville ?? 'la ville d\'exploitation'}, le $dateDebutFormat, en 2 exemplaires originaux.',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Le Bailleur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        const Text('(Mention "Lu et approuvé")', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                        const SizedBox(height: 10),
                                        Text(
                                          contrat.signeParBailleur ? '✓ Signé le $dateDebutFormat' : '[ En attente de signature ]',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: contrat.signeParBailleur ? const Color(0xFF10B981) : AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Le Preneur / Locataire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                        const Text('(Mention "Lu et approuvé")', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                                        const SizedBox(height: 10),
                                        Text(
                                          contrat.signeParLocataire ? '✓ Signé le $dateDebutFormat' : '[ En attente de signature ]',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5,
                                            color: contrat.signeParLocataire ? const Color(0xFF10B981) : AppColors.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildFichePartie({
    required String titre,
    required String nom,
    String? telephone,
    String? adresse,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.ink)),
          const SizedBox(height: 3),
          Text(nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          if (telephone != null && telephone.isNotEmpty) Text('Tél : $telephone', style: const TextStyle(fontSize: 12)),
          if (adresse != null && adresse.isNotEmpty) Text('Adresse : $adresse', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  static Widget _buildArticlePaper(String titre, String corps) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titre,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            corps,
            style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.ink),
          ),
        ],
      ),
    );
  }

  static String _genererTexteContrat(
    ContratBail contrat,
    BienImmobilier? bien,
    Contact? locataire,
    Contact? proprietaire,
    String dateDebut,
    String dateFin,
    String devise,
    AppLocalizations l10n,
  ) {
    return '''
CONTRAT DE BAIL / LOCATION (${contrat.typeBail.libelle.toUpperCase()})
Référence : ${contrat.reference}

ENTRE LES SOUSSIGNÉS :
1. LE BAILLEUR : ${proprietaire?.nomAffiche ?? 'Non spécifié'}
Tél : ${proprietaire?.telephone ?? 'N/A'} - Adresse : ${proprietaire?.adresse ?? proprietaire?.ville ?? 'N/A'}

2. LE PRENEUR (LOCATAIRE) : ${locataire?.nomAffiche ?? 'Non spécifié'}
Tél : ${locataire?.telephone ?? 'N/A'} - Adresse : ${locataire?.adresse ?? locataire?.ville ?? 'N/A'}

ARTICLE 1 — OBJET DU CONTRAT
Le Bailleur donne en location au Preneur le bien suivant :
Nom : ${bien?.nom ?? 'Bien sous contrat'}
Adresse : ${bien?.adresseComplete ?? 'N/A'}
Type : ${bien?.type.libelle ?? contrat.typeBail.libelle}

ARTICLE 2 — DURÉE ET PREAVIS
Prise d'effet le $dateDebut jusqu'au $dateFin.
Reconduction tacite : ${contrat.reconductionTacite ? 'OUI' : 'NON'}
Préavis de congé : ${contrat.preavisMois} mois.

ARTICLE 3 — CONDITIONS FINANCIÈRES
Loyer mensuel principal : ${l10n.montant(contrat.loyerMensuel, devise)}
Charges mensuelles : ${l10n.montant(contrat.chargesMensuelles, devise)}
TOTAL MENSUEL : ${l10n.montant(contrat.totalMensuel, devise)}
Échéance : au plus tard le ${contrat.termePaiementJour} du mois (${contrat.termeType == TermePaiementType.aEchoir ? 'terme à échoir' : 'terme échu'}).
Dépôt de garantie : ${l10n.montant(contrat.depotGarantie, devise)}.

ARTICLE 4 — CLAUSES PARTICULIÈRES
${contrat.clausesParticulieres?.isNotEmpty == true ? contrat.clausesParticulieres : 'Néant.'}

Fait à ${bien?.ville ?? 'DubaGest'}, le $dateDebut.
''';
  }

  Future<void> _signer(
    WidgetRef ref,
    ContratBail contrat, {
    bool bailleur = false,
    bool locataire = false,
  }) async {
    await ref.read(immobilierRepositoryProvider).signerContrat(
          contrat.id,
          bailleur: bailleur,
          locataire: locataire,
        );
    ref.invalidate(contratsListProvider);
    ref.invalidate(contratDetailsProvider(contrat.id));
  }

  Future<void> _changerStatut(
    WidgetRef ref,
    ContratBail contrat,
    StatutContratBail nouveauStatut,
  ) async {
    await ref.read(immobilierRepositoryProvider).changerStatutContrat(contrat.id, nouveauStatut);
    ref.invalidate(contratsListProvider);
    ref.invalidate(contratDetailsProvider(contrat.id));
  }
}

class _TagCarac extends StatelessWidget {
  const _TagCarac({required this.icone, required this.label});
  final IconData icone;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
