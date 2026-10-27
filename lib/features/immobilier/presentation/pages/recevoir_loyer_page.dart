import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/recu_loyer_confirmation_dialog.dart';

/// Écran complet et moderne « Recevoir un loyer ».
/// Permet l'encaissement d'un loyer total, partiel, d'avance ou multi-périodes
/// avec intégration financière unique, émission de quittance/reçu, et partage WhatsApp/PDF.
class RecevoirLoyerPage extends ConsumerStatefulWidget {
  const RecevoirLoyerPage({
    super.key,
    this.echeanceIdInitiale,
    this.bienIdInitial,
    this.locataireIdInitial,
  });

  final String? echeanceIdInitiale;
  final String? bienIdInitial;
  final String? locataireIdInitial;

  @override
  ConsumerState<RecevoirLoyerPage> createState() => _RecevoirLoyerPageState();
}

class _RecevoirLoyerPageState extends ConsumerState<RecevoirLoyerPage> {
  final _formKey = GlobalKey<FormState>();

  String? _bienIdSelectionne;
  String? _echeanceIdSelectionnee;

  late final TextEditingController _montantController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  DateTime _datePaiement = DateTime.now();
  ModePaiement _modePaiement = ModePaiement.especes;
  String _fournisseurMobile = 'ORANGE'; // 'ORANGE' ou 'MOOV' si mobileMoney
  bool _enCours = false;
  bool _initialise = false;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController();
    _referenceController = TextEditingController();
    _notesController = TextEditingController();

    _bienIdSelectionne = widget.bienIdInitial;
    _echeanceIdSelectionnee = widget.echeanceIdInitiale;
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _initialiserDepuisDonnees(List<BienImmobilier> biens, List<EcheanceLoyer> echeances) {
    if (_initialise) return;

    // Si une échéance initiale est passée
    if (widget.echeanceIdInitiale != null) {
      final ech = echeances.where((e) => e.id == widget.echeanceIdInitiale).firstOrNull;
      if (ech != null) {
        _bienIdSelectionne = ech.bienId;
        _echeanceIdSelectionnee = ech.id;
        _montantController.text = ech.resteAPayer.toString();
        _initialise = true;
        return;
      }
    }

    // Si un locataire initial est passé
    if (widget.locataireIdInitial != null) {
      final ech = echeances
          .where((e) => e.locataireId == widget.locataireIdInitial && e.resteAPayer > 0)
          .firstOrNull;
      if (ech != null) {
        _bienIdSelectionne = ech.bienId;
        _echeanceIdSelectionnee = ech.id;
        _montantController.text = ech.resteAPayer.toString();
        _initialise = true;
        return;
      }
    }

    // Si un bien initial est passé
    if (_bienIdSelectionne != null) {
      final ech = echeances
          .where((e) => e.bienId == _bienIdSelectionne && e.resteAPayer > 0)
          .firstOrNull;
      if (ech != null) {
        _echeanceIdSelectionnee = ech.id;
        _montantController.text = ech.resteAPayer.toString();
      }
      _initialise = true;
      return;
    }

    // Sélection par défaut du premier bien ayant une échéance impayée
    final premierImpaye = echeances.where((e) => e.resteAPayer > 0).firstOrNull;
    if (premierImpaye != null) {
      _bienIdSelectionne = premierImpaye.bienId;
      _echeanceIdSelectionnee = premierImpaye.id;
      _montantController.text = premierImpaye.resteAPayer.toString();
    } else if (biens.isNotEmpty) {
      _bienIdSelectionne = biens.first.id;
    }
    _initialise = true;
  }

  Future<void> _choisirDate() async {
    final nouvelleDate = await showDatePicker(
      context: context,
      initialDate: _datePaiement,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (nouvelleDate != null) {
      setState(() => _datePaiement = nouvelleDate);
    }
  }

  Future<void> _confirmerEncaissement(BienImmobilier bien, Contact? locataire, ContratBail? contrat) async {
    if (!_formKey.currentState!.validate()) return;

    final montant = int.tryParse(_montantController.text.trim()) ?? 0;
    if (montant <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un montant valide supérieur à 0.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _enCours = true);

    try {
      String? refFinale = _referenceController.text.trim();
      if (_modePaiement == ModePaiement.mobileMoney) {
        final prefix = _fournisseurMobile == 'ORANGE' ? 'Orange Money' : 'Moov Money';
        if (refFinale.isNotEmpty) {
          refFinale = '$prefix - $refFinale';
        } else {
          refFinale = prefix;
        }
      }

      final resultat = await ref.read(immobilierLoyersControllerProvider.notifier).recevoirLoyer(
            bienId: bien.id,
            locataireId: locataire?.id ?? contrat?.locataireId ?? '',
            contratId: contrat?.id,
            echeanceId: _echeanceIdSelectionnee,
            montantVerse: montant,
            modePaiement: _modePaiement,
            datePaiement: _datePaiement,
            referencePaiement: refFinale.isEmpty ? null : refFinale,
            note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            emettreDocument: true,
          );

      if (!mounted) return;
      setState(() => _enCours = false);

      // Afficher le modal du reçu professionnel avec options d'impression et de partage
      await RecuLoyerConfirmationDialog.afficher(
        context,
        resultat: resultat,
        onNouveauPaiement: () {
          setState(() {
            _montantController.clear();
            _referenceController.clear();
            _notesController.clear();
            _echeanceIdSelectionnee = null;
            _initialise = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _enCours = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'encaissement : $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final fmt = NumberFormat('#,##0', 'fr');

    final biensAsync = ref.watch(biensListProvider);
    final echeancesAsync = ref.watch(echeancesLoyersProvider);
    final contratsAsync = ref.watch(contratsListProvider);
    final contactsAsync = ref.watch(contactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recevoir un loyer'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historique des loyers',
            onPressed: () => context.push(Routes.immobilierLoyers),
          ),
        ],
      ),
      body: biensAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MessageView(
          icon: Icons.error_outline,
          title: 'Erreur',
          message: err.toString(),
        ),
        data: (biens) {
          final echeances = echeancesAsync.value ?? const [];
          final contrats = contratsAsync.value ?? const [];
          final contacts = contactsAsync.value ?? const [];

          if (biens.isEmpty) {
            return const MessageView(
              icon: Icons.apartment_rounded,
              title: 'Aucun bien immobilier enregistré',
              message: 'Ajoutez un bien et un contrat de bail pour pouvoir recevoir des loyers.',
            );
          }

          _initialiserDepuisDonnees(biens, echeances);

          final bienActuel = biens.where((b) => b.id == _bienIdSelectionne).firstOrNull ?? biens.first;
          final contratActif = contrats
              .where((c) => c.bienId == bienActuel.id && c.statut == StatutContratBail.actif)
              .firstOrNull;

          final locataire = contacts.where((c) => c.id == (contratActif?.locataireId ?? '')).firstOrNull;

          // Échéances impayées associées à ce bien/contrat
          final echeancesImpayees = echeances
              .where((e) => e.bienId == bienActuel.id && e.resteAPayer > 0 && e.statut != StatutEcheanceLoyer.annule)
              .toList()
            ..sort((a, b) => a.dateExigibilite.compareTo(b.dateExigibilite));

          // Échéance ciblée
          final echeanceCible = echeancesImpayees.where((e) => e.id == _echeanceIdSelectionnee).firstOrNull ??
              echeancesImpayees.firstOrNull;

          final montantSaisi = int.tryParse(_montantController.text.trim()) ?? 0;
          final totalResteDu = echeanceCible?.resteAPayer ?? (contratActif?.totalMensuel ?? 0);
          final estSoldeTotalPrevu = montantSaisi >= totalResteDu && totalResteDu > 0;
          final avancePrevue = montantSaisi > totalResteDu && totalResteDu > 0;

          final datePaiementFormat =
              '${_datePaiement.day.toString().padLeft(2, '0')}/${_datePaiement.month.toString().padLeft(2, '0')}/${_datePaiement.year}';

          return Form(
            key: _formKey,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  children: [
                    // 1. CARTE SÉLECTION DU BIEN & LOCATAIRE
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.apartment_rounded, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Bien & Locataire',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Sélecteur de bien immobilier
                            DropdownButtonFormField<String>(
                              value: bienActuel.id,
                              decoration: InputDecoration(
                                labelText: 'Bien immobilier concerné',
                                prefixIcon: const Icon(Icons.home_work_outlined),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: biens.map((b) {
                                return DropdownMenuItem<String>(
                                  value: b.id,
                                  child: Text('${b.nom} (${b.reference})', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (id) {
                                if (id == null) return;
                                setState(() {
                                  _bienIdSelectionne = id;
                                  final nouvellesEch = echeances
                                      .where((e) => e.bienId == id && e.resteAPayer > 0)
                                      .toList()
                                    ..sort((a, b) => a.dateExigibilite.compareTo(b.dateExigibilite));
                                  if (nouvellesEch.isNotEmpty) {
                                    _echeanceIdSelectionnee = nouvellesEch.first.id;
                                    _montantController.text = nouvellesEch.first.resteAPayer.toString();
                                  } else {
                                    _echeanceIdSelectionnee = null;
                                    _montantController.clear();
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            // Fiche du locataire et bail actif
                            if (locataire != null)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    ContactAvatar(contact: locataire, radius: 24),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            locataire.nomAffiche,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            locataire.telephone ?? 'Pas de numéro enregistré',
                                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                                          ),
                                          if (contratActif != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Bail : ${contratActif.reference} • Loyer prévu : ${fmt.format(contratActif.totalMensuel)} $devise/mois',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Aucun contrat de bail actif assigné à ce bien pour le moment.',
                                        style: TextStyle(fontSize: 12.5, color: Color(0xFFB45309)),
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

                    // 2. CARTE ÉCHÉANCE & SITUATION FINANCIÈRE
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF01226C).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF01226C), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Période & Montants Dus',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (echeancesImpayees.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                value: echeanceCible?.id,
                                decoration: InputDecoration(
                                  labelText: 'Sélectionner l\'échéance à régler',
                                  prefixIcon: const Icon(Icons.calendar_month_outlined),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: echeancesImpayees.map((ech) {
                                  final enRetard = ech.estEnRetardCalcule(DateTime.now());
                                  return DropdownMenuItem<String>(
                                    value: ech.id,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(ech.periodeLibelle),
                                        Text(
                                          'Reste : ${fmt.format(ech.resteAPayer)} $devise${enRetard ? ' (Retard)' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: enRetard ? const Color(0xFFEF4444) : AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  final ech = echeancesImpayees.where((e) => e.id == id).firstOrNull;
                                  setState(() {
                                    _echeanceIdSelectionnee = id;
                                    if (ech != null) {
                                      _montantController.text = ech.resteAPayer.toString();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 14),

                              // Détail financier de l'échéance sélectionnée
                              if (echeanceCible != null)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    children: [
                                      _buildLigneResume('Loyer net mensuel', '${fmt.format(echeanceCible.loyerNet)} $devise'),
                                      if (echeanceCible.charges > 0) ...[
                                        const SizedBox(height: 6),
                                        _buildLigneResume('Charges locatives', '${fmt.format(echeanceCible.charges)} $devise'),
                                      ],
                                      const SizedBox(height: 6),
                                      _buildLigneResume('Total prévu de la période', '${fmt.format(echeanceCible.totalDu)} $devise', gras: true),
                                      if (echeanceCible.montantRegle > 0) ...[
                                        const SizedBox(height: 6),
                                        _buildLigneResume('Déjà perçu (acomptes)', '${fmt.format(echeanceCible.montantRegle)} $devise', couleur: const Color(0xFF10B981)),
                                      ],
                                      const Divider(height: 16, color: AppColors.border),
                                      _buildLigneResume(
                                        'Solde impayé de cette période',
                                        '${fmt.format(echeanceCible.resteAPayer)} $devise',
                                        gras: true,
                                        grand: true,
                                        couleur: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Toutes les échéances générées pour ce bien sont actuellement à jour ! '
                                        'Toute somme versée sera affectée comme avance sur le mois suivant.',
                                        style: TextStyle(fontSize: 13, color: Colors.green.shade800),
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
                    const SizedBox(height: 16),

                    // 3. CARTE SAISIE DU RÈGLEMENT
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.border, width: 1.2),
                      ),
                      color: AppColors.surface,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Détails du Paiement',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Montant reçu
                            TextFormField(
                              controller: _montantController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                              decoration: InputDecoration(
                                labelText: 'Montant effectivement reçu ($devise) *',
                                prefixIcon: const Icon(Icons.attach_money_rounded),
                                suffixText: devise,
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (val) {
                                final n = int.tryParse(val ?? '') ?? 0;
                                if (n <= 0) return 'Veuillez saisir un montant supérieur à 0';
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 10),

                            // Raccourcis de remplissage rapide
                            if (echeanceCible != null && echeanceCible.resteAPayer > 0)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    ActionChip(
                                      label: Text('Solde total (${fmt.format(echeanceCible.resteAPayer)} $devise)'),
                                      avatar: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.primary),
                                      onPressed: () {
                                        setState(() {
                                          _montantController.text = echeanceCible.resteAPayer.toString();
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    if (echeanceCible.resteAPayer > 10000)
                                      ActionChip(
                                        label: Text('50% (${fmt.format((echeanceCible.resteAPayer / 2).round())} $devise)'),
                                        onPressed: () {
                                          setState(() {
                                            _montantController.text = (echeanceCible.resteAPayer ~/ 2).toString();
                                          });
                                        },
                                      ),
                                    const SizedBox(width: 8),
                                    if (contratActif != null)
                                      ActionChip(
                                        label: Text('2 Mois (${fmt.format(contratActif.totalMensuel * 2)} $devise)'),
                                        onPressed: () {
                                          setState(() {
                                            _montantController.text = (contratActif.totalMensuel * 2).toString();
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Date de réception
                            InkWell(
                              onTap: _choisirDate,
                              borderRadius: BorderRadius.circular(12),
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Date réelle de réception',
                                  prefixIcon: const Icon(Icons.event_available_rounded),
                                  suffixIcon: const Icon(Icons.edit_calendar_rounded, size: 20),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  datePaiementFormat,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Modes de paiement
                            const Text(
                              'Mode de paiement :',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildModePaiementChip(ModePaiement.especes, 'Espèces', Icons.payments_outlined),
                                _buildMobileMoneyChip('ORANGE', 'Orange Money'),
                                _buildMobileMoneyChip('MOOV', 'Moov Money'),
                                _buildModePaiementChip(ModePaiement.virement, 'Virement bancaire', Icons.account_balance_outlined),
                                _buildModePaiementChip(ModePaiement.cheque, 'Chèque', Icons.description_outlined),
                                _buildModePaiementChip(ModePaiement.autre, 'Autre mode', Icons.more_horiz_rounded),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Référence de transaction
                            TextFormField(
                              controller: _referenceController,
                              decoration: InputDecoration(
                                labelText: 'Référence de transaction (Facultatif)',
                                hintText: _modePaiement == ModePaiement.mobileMoney
                                    ? 'Ex: ID transaction OM/Moov (OM123456)'
                                    : 'Ex: N° de chèque ou référence de virement',
                                prefixIcon: const Icon(Icons.tag_rounded),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Observations / Remarques
                            TextFormField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Observations / Remarques (Facultatif)',
                                hintText: 'Commentaire interne sur l\'encaissement...',
                                prefixIcon: const Icon(Icons.notes_rounded),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 4. RÉCAPITULATIF VISUEL AVANT VALIDATION
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: estSoldeTotalPrevu
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: estSoldeTotalPrevu
                              ? const Color(0xFF10B981).withValues(alpha: 0.3)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                estSoldeTotalPrevu ? Icons.verified_rounded : Icons.info_outline,
                                color: estSoldeTotalPrevu ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                estSoldeTotalPrevu
                                    ? 'Paiement intégral — Quittance émise'
                                    : 'Paiement partiel — Reçu d\'acompte émis',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: estSoldeTotalPrevu ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            estSoldeTotalPrevu
                                ? 'Ce paiement soldera intégralement l\'échéance de ${echeanceCible?.periodeLibelle ?? 'la période'}. Une quittance officielle sera générée.'
                                : 'Montant versé : ${fmt.format(montantSaisi)} $devise. Il restera dû ${fmt.format((totalResteDu - montantSaisi).clamp(0, totalResteDu))} $devise sur cette échéance.',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.ink),
                          ),
                          if (avancePrevue) ...[
                            const SizedBox(height: 6),
                            Text(
                              '💡 L\'excédent de ${fmt.format(montantSaisi - totalResteDu)} $devise sera automatiquement alloué aux échéances suivantes du bail.',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. BOUTON PRINCIPAL UNIQUE : CONFIRMER L'ENCAISSEMENT
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: _enCours ? null : () => _confirmerEncaissement(bienActuel, locataire, contratActif),
                      child: _enCours
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 20),
                                SizedBox(width: 10),
                                Text(
                                  'Confirmer l\'encaissement',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModePaiementChip(ModePaiement mode, String label, IconData icon) {
    final estChoisi = _modePaiement == mode && (_modePaiement != ModePaiement.mobileMoney);
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: estChoisi ? Colors.white : AppColors.ink),
      selected: estChoisi,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: estChoisi ? Colors.white : AppColors.ink,
      ),
      onSelected: (_) {
        setState(() => _modePaiement = mode);
      },
    );
  }

  Widget _buildMobileMoneyChip(String fournisseur, String label) {
    final estChoisi = _modePaiement == ModePaiement.mobileMoney && _fournisseurMobile == fournisseur;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(Icons.phone_android_rounded, size: 16, color: estChoisi ? Colors.white : AppColors.ink),
      selected: estChoisi,
      selectedColor: fournisseur == 'ORANGE' ? const Color(0xFFFF6600) : const Color(0xFF005BA6),
      labelStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: estChoisi ? Colors.white : AppColors.ink,
      ),
      onSelected: (_) {
        setState(() {
          _modePaiement = ModePaiement.mobileMoney;
          _fournisseurMobile = fournisseur;
        });
      },
    );
  }

  Widget _buildLigneResume(String label, String valeur, {bool gras = false, bool grand = false, Color? couleur}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: grand ? 14 : 12.5, color: AppColors.muted, fontWeight: gras ? FontWeight.w700 : FontWeight.w500),
        ),
        Text(
          valeur,
          style: TextStyle(
            fontSize: grand ? 16 : 13,
            fontWeight: gras ? FontWeight.w900 : FontWeight.w600,
            color: couleur ?? AppColors.ink,
          ),
        ),
      ],
    );
  }
}
