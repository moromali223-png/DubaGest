import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/localization/l10n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../documents/domain/entities/document.dart';
import '../../../documents/presentation/providers/documents_providers.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../../finances/domain/entities/finances.dart';
import '../../../finances/presentation/widgets/caisse_labels.dart';
import '../../domain/entities/echeance_loyer.dart';
import '../providers/immobilier_providers.dart';

String _nomMode(ModePaiement m) => switch (m) {
      ModePaiement.especes => 'Espèces',
      ModePaiement.mobileMoney => 'Mobile Money',
      ModePaiement.carte => 'Carte bancaire',
      ModePaiement.virement => 'Virement bancaire',
      ModePaiement.cheque => 'Chèque',
      ModePaiement.autre => 'Autre mode',
    };

/// Fonction utilitaire pour afficher le dialogue d'encaissement de loyer.
Future<void> afficherDialogueEncaissement(BuildContext context, EcheanceLoyer echeance) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => EncaisserLoyerDialog(echeance: echeance),
  );
}

class EncaisserLoyerDialog extends ConsumerStatefulWidget {
  const EncaisserLoyerDialog({super.key, required this.echeance});

  final EcheanceLoyer echeance;

  @override
  ConsumerState<EncaisserLoyerDialog> createState() => _EncaisserLoyerDialogState();
}

class _EncaisserLoyerDialogState extends ConsumerState<EncaisserLoyerDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montantController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;

  ModePaiement _modePaiement = ModePaiement.especes;
  DateTime _datePaiement = DateTime.now();
  bool _genererDocument = true;
  bool _chargement = false;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(text: widget.echeance.resteAPayer.toString());
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _validerEncaissement() async {
    if (!_formKey.currentState!.validate()) return;

    final montant = int.tryParse(_montantController.text.trim()) ?? 0;
    if (montant <= 0) return;

    setState(() => _chargement = true);

    try {
      final ctx = ref.read(contexteActifProvider);
      final devise = ctx?.entreprise?.devise ?? 'FCFA';
      final echeance = widget.echeance;
      final solde = (echeance.montantRegle + montant) >= echeance.totalDu;

      String? quittanceId;
      String? recuId;

      if (_genererDocument && ctx != null) {
        final appareilId = ref.read(appareilIdProvider);
        final contacts = ref.read(contactsProvider).value ?? const [];
        final locataire = contacts.where((c) => c.id == echeance.locataireId).firstOrNull;
        final bien = (ref.read(biensListProvider).value ?? const [])
            .where((b) => b.id == echeance.bienId)
            .firstOrNull;

        final typeDoc = solde ? TypeDocument.quittance : TypeDocument.recu;
        final titreDoc = solde
            ? 'Quittance de loyer - ${echeance.periodeLibelle}'
            : 'Reçu d\'acompte de loyer - ${echeance.periodeLibelle}';

        final contenu = <String, dynamic>{
          'titre': titreDoc,
          'reference_metier': echeance.reference,
          'periode_loyer': echeance.periodeLibelle,
          'periode_mois': echeance.periodeMois,
          'periode_annee': echeance.periodeAnnee,
          'bien_nom': bien?.nom ?? 'Bien immobilier',
          'bien_adresse': bien?.adresseComplete ?? '',
          'locataire_nom': locataire?.nomAffiche ?? 'Locataire',
          'loyer_net': echeance.loyerNet,
          'charges': echeance.charges,
          'total_du': echeance.totalDu,
          'montant_verse': montant,
          'cumul_regle': echeance.montantRegle + montant,
          'reste_a_payer': (echeance.totalDu - (echeance.montantRegle + montant)).clamp(0, echeance.totalDu),
          'mode_paiement': _modePaiement.code,
          'reference_paiement': _referenceController.text.trim(),
          'statut': solde ? 'PAYE' : 'PARTIEL',
          'devise': devise,
          'notes': _notesController.text.trim(),
          'lignes': [
            {
              'description': 'Loyer net - ${echeance.periodeLibelle} (${bien?.nom ?? 'Logement'})',
              'quantite': 1,
              'prix_unitaire': echeance.loyerNet,
              'total': echeance.loyerNet,
            },
            if (echeance.charges > 0)
              {
                'description': 'Provisions sur charges locatives',
                'quantite': 1,
                'prix_unitaire': echeance.charges,
                'total': echeance.charges,
              },
          ],
        };

        try {
          final doc = await ref.read(emettreDocumentProvider).call(
                ctx,
                type: typeDoc,
                origineType: 'LOYER',
                origineId: echeance.id,
                contactId: echeance.locataireId,
                montant: montant,
                contenu: contenu,
                appareilId: appareilId,
              );
          if (solde) {
            quittanceId = doc.id;
          } else {
            recuId = doc.id;
          }
        } catch (_) {
          // Si l'émission du document échoue hors-ligne ou manque de bloc de numéros, l'encaissement financier continue
        }
      }

      await ref.read(immobilierLoyersControllerProvider.notifier).encaisserLoyer(
            echeanceId: echeance.id,
            montantVerse: montant,
            modePaiement: _modePaiement.code,
            referencePaiement: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
            note: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            datePaiement: _datePaiement,
            quittanceDocumentId: quittanceId,
            recuDocumentId: recuId,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              solde
                  ? 'Loyer soldé avec succès ! Quittance générée.'
                  : 'Acompte de ${context.l10n.montant(montant, devise)} enregistré avec succès !',
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _chargement = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'encaissement : $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final echeance = widget.echeance;

    final biens = ref.watch(biensListProvider).value ?? const [];
    final contacts = ref.watch(contactsProvider).value ?? const [];
    final bien = biens.where((b) => b.id == echeance.bienId).firstOrNull;
    final locataire = contacts.where((c) => c.id == echeance.locataireId).firstOrNull;

    final datePaiementFormat =
        '${_datePaiement.day.toString().padLeft(2, '0')}/${_datePaiement.month.toString().padLeft(2, '0')}/${_datePaiement.year}';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.payments_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Encaisser un loyer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            '${echeance.periodeLibelle} • ${echeance.reference}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _chargement ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Récapitulatif locataire & bien
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Locataire :', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          Text(
                            locataire?.nomAffiche ?? 'Locataire (#${echeance.locataireId.substring(0, 6)})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bien loué :', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          Text(
                            bien?.nom ?? 'Bien (#${echeance.bienId.substring(0, 6)})',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total dû : ${context.l10n.montant(echeance.totalDu, devise)}',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                          Text(
                            'Reste à payer : ${context.l10n.montant(echeance.resteAPayer, devise)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDF9540),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Montant du versement
                TextFormField(
                  controller: _montantController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Montant versé ($devise) *',
                    hintText: 'Ex: ${echeance.resteAPayer}',
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                    suffixText: devise,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Montant requis';
                    final n = int.tryParse(val.trim());
                    if (n == null || n <= 0) return 'Montant invalide';
                    if (n > echeance.resteAPayer) {
                      return 'Le montant ne peut pas dépasser le reste dû (${echeance.resteAPayer} $devise)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Raccourcis montants
                Row(
                  children: [
                    ActionChip(
                      label: Text('Totalité (${echeance.resteAPayer} $devise)'),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                      side: BorderSide.none,
                      onPressed: () {
                        _montantController.text = echeance.resteAPayer.toString();
                      },
                    ),
                    if (echeance.resteAPayer >= 2) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        label: Text('50 % (${(echeance.resteAPayer / 2).round()} $devise)'),
                        backgroundColor: AppColors.background,
                        side: BorderSide.none,
                        onPressed: () {
                          _montantController.text = (echeance.resteAPayer / 2).round().toString();
                        },
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                // Mode de paiement
                DropdownButtonFormField<ModePaiement>(
                  initialValue: _modePaiement,
                  decoration: const InputDecoration(
                    labelText: 'Mode de règlement *',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: ModePaiement.values.map((m) {
                    return DropdownMenuItem<ModePaiement>(
                      value: m,
                      child: Row(
                        children: [
                          Icon(iconeMode(m), size: 16, color: couleurMode(m)),
                          const SizedBox(width: 8),
                          Text(_nomMode(m)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _modePaiement = val);
                  },
                ),
                const SizedBox(height: 14),

                // Référence & Date
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextFormField(
                        controller: _referenceController,
                        decoration: const InputDecoration(
                          labelText: 'Réf. transaction',
                          hintText: 'Ex: Chèque n° / Ref OM',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: InkWell(
                        onTap: _choisirDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date paiement',
                            prefixIcon: Icon(Icons.calendar_today_rounded, size: 16),
                          ),
                          child: Text(
                            datePaiementFormat,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Note interne
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Remarques (facultatif)',
                    hintText: 'Commentaire interne sur ce versement...',
                  ),
                ),
                const SizedBox(height: 14),

                // Option document officiel
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text(
                      'Émettre la pièce justificative',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Génère automatiquement la Quittance officielle (si solde) ou le Reçu d\'acompte conforme.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    value: _genererDocument,
                    activeThumbColor: const Color(0xFF10B981),
                    onChanged: (val) => setState(() => _genererDocument = val),
                  ),
                ),
                const SizedBox(height: 22),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _chargement ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _chargement ? null : _validerEncaissement,
                      icon: _chargement
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: Text(_chargement ? 'Enregistrement...' : 'Valider l\'encaissement'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
