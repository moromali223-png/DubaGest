import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/location_immobilier.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';
import '../widgets/location_widgets.dart';

class LocationDetailsPage extends ConsumerWidget {
  const LocationDetailsPage({super.key, required this.locationId});
  final String locationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locationAsync = ref.watch(locationDetailsProvider(locationId));
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fiche d\'Occupation / Location'),
      ),
      body: locationAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(locationDetailsProvider(locationId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
          ),
        ),
        data: (location) {
          if (location == null) {
            return const MessageView(
              icon: Icons.search_off_rounded,
              title: 'Location introuvable',
              message: 'Cette location n\'existe pas ou a été supprimée.',
            );
          }

          final bien = ref.watch(bienDetailsProvider(location.bienId)).value;
          final locataire = ref.watch(contactProvider(location.locataireId)).value;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Synthèse statut et loyer
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
                          StatutLocationBadge(statut: location.statut),
                          Text(
                            '${l10n.montant(location.totalMensuel, devise)} / mois',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Text(
                            'Du ${_formatDate(location.dateDebut)} au ${location.dateFinReelle != null ? _formatDate(location.dateFinReelle!) : (location.dateFinPrevue != null ? _formatDate(location.dateFinPrevue!) : 'Durée indéterminée')}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                      if (location.dateFinReelle != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.muted),
                            const SizedBox(width: 8),
                            Text(
                              'Clôturée le ${_formatDate(location.dateFinReelle!)}${location.motifCloture != null ? ' (${location.motifCloture})' : ''}',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Le Bien immobilier loué
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.home_work_outlined, size: 20, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text(
                                'Bien immobilier loué',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                              ),
                            ],
                          ),
                          if (bien != null) StatutBienBadge(statut: bien.statut),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      if (bien != null) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(bien.type.icone, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bien.nom,
                                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Réf : ${bien.reference} • ${bien.adresseComplete}',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('Fiche du bien'),
                              onPressed: () => context.push(Routes.bienDetails(bien.id)),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Le Locataire occupant
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.person_pin_rounded, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Locataire occupant',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      if (locataire != null) ...[
                        Row(
                          children: [
                            ContactAvatar(contact: locataire, radius: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    locataire.nomAffiche,
                                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    locataire.telephone ?? locataire.ville ?? 'Aucun numéro',
                                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            if (locataire.telephone != null && locataire.telephone!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.phone_rounded, color: AppColors.green),
                                tooltip: 'Appeler',
                                onPressed: () => launchUrl(Uri.parse('tel:${locataire.telephone}')),
                              ),
                            if (locataire.whatsapp != null && locataire.whatsapp!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF128C7E)),
                                tooltip: 'WhatsApp',
                                onPressed: () {
                                  final clean = locataire.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '');
                                  launchUrl(
                                    Uri.parse('https://wa.me/$clean'),
                                    mode: LaunchMode.externalApplication,
                                  );
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('Fiche locataire'),
                              onPressed: () => context.push(Routes.locataireDetails(locataire.id)),
                            ),
                          ],
                        ),
                      ] else ...[
                        const Center(child: CircularProgressIndicator()),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Décomposition financière & Dépôt séquestré
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'Conditions Financières',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      _FinanceRow(label: 'Loyer mensuel', valeur: l10n.montant(location.loyerMensuel, devise)),
                      const SizedBox(height: 8),
                      _FinanceRow(
                        label: 'Charges mensuelles',
                        valeur: location.chargesMensuelles > 0 ? l10n.montant(location.chargesMensuelles, devise) : 'Incluses / Néant',
                      ),
                      const Divider(height: 16, color: AppColors.border),
                      _FinanceRow(
                        label: 'Total exigible par période',
                        valeur: l10n.montant(location.totalMensuel, devise),
                        isBold: true,
                        couleur: AppColors.primary,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDF9540).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDF9540).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dépôt de garantie séquestré',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                                ),
                                Text(
                                  'Séparé du chiffre d\'affaires locatif',
                                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                            Text(
                              l10n.montant(location.depotGarantie, devise),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFDF9540),
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

              // 5. États des lieux et Remarques
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text(
                            'États des Lieux & Clauses',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                        ],
                      ),
                      const Divider(height: 20, color: AppColors.border),
                      Row(
                        children: [
                          Icon(
                            location.etatLieuxEntree ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: location.etatLieuxEntree ? const Color(0xFF10B981) : AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            location.etatLieuxEntree ? 'État des lieux d\'entrée validé' : 'Aucun état des lieux d\'entrée consigné',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            location.etatLieuxSortie ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                            color: location.etatLieuxSortie ? const Color(0xFF10B981) : AppColors.muted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            location.etatLieuxSortie ? 'État des lieux de sortie effectué' : 'État des lieux de sortie en attente',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (location.remarques != null && location.remarques!.trim().isNotEmpty) ...[
                        const Divider(height: 20, color: AppColors.border),
                        const Text(
                          'Notes particulières :',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.remarques!,
                          style: const TextStyle(fontSize: 13, color: AppColors.ink),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton d'action Clôturer / Sortie des lieux
              if (location.estActive || location.estEnAttente) ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.exit_to_app_rounded),
                  label: const Text(
                    'Clôturer la location / Sortie des lieux',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => _ouvrirModalCloture(context, ref, location),
                ),
                const SizedBox(height: 32),
              ],
            ],
          );
        },
      ),
    );
  }

  void _ouvrirModalCloture(BuildContext context, WidgetRef ref, LocationImmobilier location) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.75,
        child: _ClotureLocationSheet(location: location),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FinanceRow extends StatelessWidget {
  const _FinanceRow({
    required this.label,
    required this.valeur,
    this.isBold = false,
    this.couleur,
  });

  final String label;
  final String valeur;
  final bool isBold;
  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isBold ? AppColors.ink : AppColors.muted,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          valeur,
          style: TextStyle(
            fontSize: isBold ? 15 : 13.5,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: couleur ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _ClotureLocationSheet extends ConsumerStatefulWidget {
  const _ClotureLocationSheet({required this.location});
  final LocationImmobilier location;

  @override
  ConsumerState<_ClotureLocationSheet> createState() => _ClotureLocationSheetState();
}

class _ClotureLocationSheetState extends ConsumerState<_ClotureLocationSheet> {
  DateTime _dateSortie = DateTime.now();
  late final _motifCtrl = TextEditingController(text: 'Fin normale de bail');
  StatutBien _futurStatutBien = StatutBien.disponible;
  bool _chargement = false;

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectionnerDateSortie() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateSortie,
      firstDate: widget.location.dateDebut,
      lastDate: DateTime(2045),
    );
    if (picked != null) {
      setState(() => _dateSortie = picked);
    }
  }

  Future<void> _validerCloture() async {
    setState(() => _chargement = true);

    try {
      await ref.read(immobilierRepositoryProvider).cloturerLocation(
            widget.location.id,
            dateSortie: _dateSortie,
            motif: _motifCtrl.text.trim().isEmpty ? 'Sortie des lieux' : _motifCtrl.text.trim(),
            futurStatutBien: _futurStatutBien,
          );

      ref.invalidate(locationDetailsProvider(widget.location.id));
      ref.invalidate(locationsListProvider);
      ref.invalidate(biensListProvider);
      ref.invalidate(parcOccupationStatistiquesProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La location a été clôturée et le bien a été actualisé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Clôture et Sortie des Lieux',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.border),
          const Text(
            'En clôturant cette location, vous attestez du départ du locataire et de la fin de l\'occupation.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 16),

          // Date effective de sortie
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectionnerDateSortie,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date effective de sortie des lieux *',
                prefixIcon: Icon(Icons.event_available_rounded),
              ),
              child: Text(
                '${_dateSortie.day.toString().padLeft(2, '0')}/${_dateSortie.month.toString().padLeft(2, '0')}/${_dateSortie.year}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Motif de clôture
          TextFormField(
            controller: _motifCtrl,
            decoration: const InputDecoration(
              labelText: 'Motif de départ / Clôture',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 14),

          // Devenir du bien
          DropdownButtonFormField<StatutBien>(
            initialValue: _futurStatutBien,
            decoration: const InputDecoration(
              labelText: 'Statut du bien après le départ',
              prefixIcon: Icon(Icons.home_repair_service_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: StatutBien.disponible,
                child: Text('Disponible à la location (Remis sur le marché)'),
              ),
              DropdownMenuItem(
                value: StatutBien.enTravaux,
                child: Text('En travaux / Remise en état nécessaire'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _futurStatutBien = val);
            },
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _chargement ? null : _validerCloture,
              child: _chargement
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Confirmer la sortie et libérer le bien',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
