import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../contacts/domain/entities/contact.dart';
import '../../../contacts/presentation/providers/contacts_providers.dart';
import '../../../contacts/presentation/widgets/contact_avatar.dart';
import '../../../entreprise/presentation/providers/contexte_providers.dart';
import '../../domain/entities/bien_immobilier.dart';
import '../../domain/entities/contrat_bail.dart';
import '../providers/immobilier_providers.dart';
import '../widgets/immobilier_widgets.dart';
import '../widgets/locataire_widgets.dart';
import '../widgets/location_widgets.dart';
import '../../../services/presentation/widgets/devis_contact_widgets.dart';

class ContratFormPage extends ConsumerStatefulWidget {
  const ContratFormPage({
    super.key,
    this.contratId,
    this.initialBienId,
    this.initialLocataireId,
  });

  final String? contratId;
  final String? initialBienId;
  final String? initialLocataireId;

  @override
  ConsumerState<ContratFormPage> createState() => _ContratFormPageState();
}

class _ContratFormPageState extends ConsumerState<ContratFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _referenceCtrl;
  late final TextEditingController _loyerCtrl;
  late final TextEditingController _chargesCtrl;
  late final TextEditingController _depotCtrl;
  late final TextEditingController _dureeMoisCtrl;
  late final TextEditingController _preavisMoisCtrl;
  late final TextEditingController _jourPaiementCtrl;
  late final TextEditingController _penaliteCtrl;
  late final TextEditingController _clausesCtrl;

  BienImmobilier? _bienSelectionne;
  Contact? _locataireSelectionne;
  Contact? _proprietaireSelectionne;

  TypeBail _typeBail = TypeBail.habitationNue;
  StatutContratBail _statut = StatutContratBail.brouillon;
  TermePaiementType _termeType = TermePaiementType.aEchoir;

  DateTime _dateDebut = DateTime.now();
  DateTime? _dateFinPrevue;
  bool _reconductionTacite = true;

  bool _signeBailleur = false;
  bool _signeLocataire = false;
  DateTime? _dateSignature;

  bool _chargement = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _referenceCtrl = TextEditingController(text: _genererReferenceDefaut());
    _loyerCtrl = TextEditingController(text: '0');
    _chargesCtrl = TextEditingController(text: '0');
    _depotCtrl = TextEditingController(text: '0');
    _dureeMoisCtrl = TextEditingController(text: '12');
    _preavisMoisCtrl = TextEditingController(text: '1');
    _jourPaiementCtrl = TextEditingController(text: '5');
    _penaliteCtrl = TextEditingController(text: '');
    _clausesCtrl = TextEditingController();

    _calculerDateFinPrevue();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initialiser());
  }

  String _genererReferenceDefaut() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final alea = Random().nextInt(9000) + 1000;
    return 'CTR-$y$m-$alea';
  }

  void _calculerDateFinPrevue() {
    final mois = int.tryParse(_dureeMoisCtrl.text.trim()) ?? 12;
    _dateFinPrevue = DateTime(_dateDebut.year, _dateDebut.month + mois, _dateDebut.day);
  }

  Future<void> _initialiser() async {
    // Mode modification
    if (widget.contratId != null) {
      final contrat = await ref.read(contratDetailsProvider(widget.contratId!).future);
      if (contrat != null && mounted) {
        setState(() {
          _referenceCtrl.text = contrat.reference;
          _typeBail = contrat.typeBail;
          _statut = contrat.statut;
          _dateDebut = contrat.dateDebut;
          _dateFinPrevue = contrat.dateFinPrevue;
          _reconductionTacite = contrat.reconductionTacite;
          _preavisMoisCtrl.text = contrat.preavisMois.toString();
          _loyerCtrl.text = contrat.loyerMensuel.toString();
          _chargesCtrl.text = contrat.chargesMensuelles.toString();
          _depotCtrl.text = contrat.depotGarantie.toString();
          _jourPaiementCtrl.text = contrat.termePaiementJour.toString();
          _termeType = contrat.termeType;
          _penaliteCtrl.text = contrat.penaliteRetardPourcent?.toString() ?? '';
          _clausesCtrl.text = contrat.clausesParticulieres ?? '';
          _signeBailleur = contrat.signeParBailleur;
          _signeLocataire = contrat.signeParLocataire;
          _dateSignature = contrat.dateSignature;
        });

        final bien = await ref.read(immobilierRepositoryProvider).getBien(contrat.bienId);
        if (bien != null && mounted) setState(() => _bienSelectionne = bien);

        final locataire = await ref.read(contactProvider(contrat.locataireId).future);
        if (locataire != null && mounted) setState(() => _locataireSelectionne = locataire);

        final proprietaire = await ref.read(contactProvider(contrat.proprietaireId).future);
        if (proprietaire != null && mounted) setState(() => _proprietaireSelectionne = proprietaire);
      }
      return;
    }

    // Mode création avec pré-remplissage
    if (widget.initialBienId != null) {
      final bien = await ref.read(immobilierRepositoryProvider).getBien(widget.initialBienId!);
      if (bien != null && mounted) {
        _appliquerBien(bien);
      }
    }

    if (widget.initialLocataireId != null) {
      final locataire = await ref.read(contactProvider(widget.initialLocataireId!).future);
      if (locataire != null && mounted) {
        setState(() => _locataireSelectionne = locataire);
      }
    }
  }

  void _appliquerBien(BienImmobilier bien) async {
    setState(() {
      _bienSelectionne = bien;
      _loyerCtrl.text = bien.loyerReference.toString();
      _depotCtrl.text = bien.depotGarantiePrevu.toString();
    });

    final prop = await ref.read(contactProvider(bien.proprietaireId).future);
    if (prop != null && mounted) {
      setState(() => _proprietaireSelectionne = prop);
    }
  }

  @override
  void dispose() {
    _referenceCtrl.dispose();
    _loyerCtrl.dispose();
    _chargesCtrl.dispose();
    _depotCtrl.dispose();
    _dureeMoisCtrl.dispose();
    _preavisMoisCtrl.dispose();
    _jourPaiementCtrl.dispose();
    _penaliteCtrl.dispose();
    _clausesCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectionnerDateDebut() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateDebut,
      firstDate: DateTime(2020),
      lastDate: DateTime(2045),
    );
    if (picked != null) {
      setState(() {
        _dateDebut = picked;
        _calculerDateFinPrevue();
      });
    }
  }

  Future<void> _selectionnerDateFinPrevue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFinPrevue ?? _dateDebut.add(const Duration(days: 365)),
      firstDate: _dateDebut,
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _dateFinPrevue = picked);
    }
  }

  Future<void> _selectionnerDateSignature() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateSignature ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _dateSignature = picked);
    }
  }

  Future<void> _sauvegarder() async {
    setState(() => _erreur = null);

    if (_bienSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un bien immobilier.')),
      );
      return;
    }

    if (_locataireSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un locataire.')),
      );
      return;
    }

    if (_proprietaireSelectionne == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez désigner le propriétaire bailleur.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final loyer = int.tryParse(_loyerCtrl.text.replaceAll(' ', '')) ?? 0;
    final charges = int.tryParse(_chargesCtrl.text.replaceAll(' ', '')) ?? 0;
    final depot = int.tryParse(_depotCtrl.text.replaceAll(' ', '')) ?? 0;
    final preavis = int.tryParse(_preavisMoisCtrl.text.trim()) ?? 1;
    final jourPaiement = int.tryParse(_jourPaiementCtrl.text.trim()) ?? 5;
    final penalite = double.tryParse(_penaliteCtrl.text.trim().replaceAll(',', '.'));

    setState(() => _chargement = true);

    try {
      final ctx = ref.read(contexteActifProvider);
      if (ctx == null || ctx.entreprise == null) return;

      final contrat = ContratBail(
        id: widget.contratId ?? const Uuid().v4(),
        entrepriseId: ctx.entreprise!.id,
        reference: _referenceCtrl.text.trim(),
        bienId: _bienSelectionne!.id,
        proprietaireId: _proprietaireSelectionne!.id,
        locataireId: _locataireSelectionne!.id,
        typeBail: _typeBail,
        statut: _statut,
        dateDebut: _dateDebut,
        dateFinPrevue: _dateFinPrevue,
        reconductionTacite: _reconductionTacite,
        preavisMois: preavis,
        loyerMensuel: loyer,
        chargesMensuelles: charges,
        termePaiementJour: jourPaiement,
        termeType: _termeType,
        depotGarantie: depot,
        penaliteRetardPourcent: penalite,
        clausesParticulieres: _clausesCtrl.text.trim().isEmpty ? null : _clausesCtrl.text.trim(),
        dateSignature: _dateSignature,
        signeParBailleur: _signeBailleur,
        signeParLocataire: _signeLocataire,
        creeLe: DateTime.now(),
        misAJourLe: DateTime.now(),
      );

      final sauve = await ref.read(immobilierRepositoryProvider).sauvegarderContrat(contrat);

      ref.invalidate(contratsListProvider);
      ref.invalidate(contratDetailsProvider(sauve.id));

      if (mounted) {
        context.go(Routes.contratDetails(sauve.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contrat de bail enregistré avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erreur = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctx = ref.watch(contexteActifProvider);
    final devise = ctx?.entreprise?.devise ?? 'FCFA';
    final estModif = widget.contratId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(estModif ? 'Modifier le Contrat' : 'Nouveau Contrat de Bail'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_erreur != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _erreur!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. IDENTIFICATION & STATUT
            const Text(
              '1. IDENTIFICATION & TYPE DU CONTRAT',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _referenceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numéro / Référence *',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<StatutContratBail>(
                    isExpanded: true,
                    initialValue: _statut,
                    decoration: const InputDecoration(
                      labelText: 'Statut du contrat *',
                    ),
                    items: StatutContratBail.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(s.icone, size: 16, color: s.couleur),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                s.libelle,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _statut = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<TypeBail>(
              isExpanded: true,
              initialValue: _typeBail,
              decoration: const InputDecoration(
                labelText: 'Nature juridique du bail *',
                prefixIcon: Icon(Icons.gavel_outlined),
              ),
              items: TypeBail.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Row(
                    children: [
                      Icon(t.icone, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(t.libelle),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _typeBail = val);
              },
            ),
            const SizedBox(height: 20),

            // 2. PARTIES PRENANTES
            const Text(
              '2. BIEN & PARTIES PRENANTES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),

            // Bien
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border, width: 1.2),
              ),
              color: AppColors.surface,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _bienSelectionne?.type.icone ?? Icons.home_work_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                  _bienSelectionne?.nom ?? 'Sélectionner le bien loué...',
                  style: TextStyle(
                    fontWeight: _bienSelectionne != null ? FontWeight.w800 : FontWeight.w500,
                    color: _bienSelectionne != null ? AppColors.ink : AppColors.muted,
                  ),
                ),
                subtitle: Text(
                  _bienSelectionne != null
                      ? 'Réf : ${_bienSelectionne!.reference} · ${_bienSelectionne!.ville ?? ''}'
                      : 'Appuyez pour choisir le bien dans votre parc',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: _bienSelectionne != null
                    ? StatutBienBadge(statut: _bienSelectionne!.statut)
                    : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: () async {
                  final b = await choisirBien(context);
                  if (b != null) _appliquerBien(b);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Locataire
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border, width: 1.2),
              ),
              color: AppColors.surface,
              child: ListTile(
                leading: _locataireSelectionne != null
                    ? ContactAvatar(contact: _locataireSelectionne!, radius: 20)
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                      ),
                title: Text(
                  _locataireSelectionne?.nomAffiche ?? 'Sélectionner le preneur (locataire)...',
                  style: TextStyle(
                    fontWeight: _locataireSelectionne != null ? FontWeight.w800 : FontWeight.w500,
                    color: _locataireSelectionne != null ? AppColors.ink : AppColors.muted,
                  ),
                ),
                subtitle: Text(
                  _locataireSelectionne != null
                      ? '${_locataireSelectionne!.telephone ?? ''} · ${_locataireSelectionne!.ville ?? ''}'
                      : 'Appuyez pour désigner le locataire',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                onTap: () async {
                  final loc = await choisirLocataire(context);
                  if (loc != null) setState(() => _locataireSelectionne = loc);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final nouveau = await DialogueNouveauContactDevis.afficher(
                        context,
                        relation: RelationContact.locataire,
                      );
                      if (nouveau != null && mounted) {
                        setState(() => _locataireSelectionne = nouveau);
                        ref.invalidate(locatairesListProvider);
                      }
                    },
                    icon: const Icon(Icons.person_add_rounded, size: 16),
                    label: const Text('+ Créer un nouveau locataire', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  ),
                ],
              ),
            ),

            // Propriétaire (Bailleur)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border, width: 1.2),
              ),
              color: AppColors.surface,
              child: ListTile(
                leading: _proprietaireSelectionne != null
                    ? ContactAvatar(contact: _proprietaireSelectionne!, radius: 20)
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDF9540).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.badge_outlined, color: Color(0xFFDF9540)),
                      ),
                title: Text(
                  _proprietaireSelectionne?.nomAffiche ?? 'Propriétaire bailleur...',
                  style: TextStyle(
                    fontWeight: _proprietaireSelectionne != null ? FontWeight.w800 : FontWeight.w500,
                    color: _proprietaireSelectionne != null ? AppColors.ink : AppColors.muted,
                  ),
                ),
                subtitle: Text(
                  _proprietaireSelectionne != null
                      ? 'Bailleur légal du contrat'
                      : 'Sélectionné automatiquement depuis le bien',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 3. DURÉE ET PÉRIODE DU BAIL
            const Text(
              '3. DURÉE & PÉRIODE DU BAIL',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _selectionnerDateDebut,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date d\'effet (début) *',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                      child: Text(
                        '${_dateDebut.day.toString().padLeft(2, '0')}/${_dateDebut.month.toString().padLeft(2, '0')}/${_dateDebut.year}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _dureeMoisCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée (mois) *',
                      prefixIcon: Icon(Icons.timelapse_rounded, size: 18),
                      suffixText: 'mois',
                    ),
                    onChanged: (_) => setState(_calculerDateFinPrevue),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Invalide';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _selectionnerDateFinPrevue,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date d\'échéance prévue',
                        prefixIcon: const Icon(Icons.event_available_rounded, size: 18),
                        suffixIcon: _dateFinPrevue != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() => _dateFinPrevue = null),
                              )
                            : null,
                      ),
                      child: Text(
                        _dateFinPrevue != null
                            ? '${_dateFinPrevue!.day.toString().padLeft(2, '0')}/${_dateFinPrevue!.month.toString().padLeft(2, '0')}/${_dateFinPrevue!.year}'
                            : 'Indéterminée',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _dateFinPrevue != null ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _preavisMoisCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Préavis de congé',
                      prefixIcon: Icon(Icons.schedule_rounded, size: 18),
                      suffixText: 'mois',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reconduction tacite', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: const Text('Le contrat est renouvelé automatiquement à son terme', style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              value: _reconductionTacite,
              onChanged: (val) => setState(() => _reconductionTacite = val),
            ),
            const SizedBox(height: 20),

            // 4. CONDITIONS FINANCIÈRES
            const Text(
              '4. CONDITIONS FINANCIÈRES & PAIEMENT',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _loyerCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Loyer mensuel net *',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: devise,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Indiquez le loyer';
                final n = int.tryParse(v.replaceAll(' ', ''));
                if (n == null || n <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chargesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Charges mensuelles',
                      prefixIcon: const Icon(Icons.water_drop_outlined, size: 18),
                      suffixText: devise,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _depotCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Dépôt de garantie',
                      prefixIcon: const Icon(Icons.savings_outlined, size: 18),
                      suffixText: devise,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDF9540).withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: Color(0xFFDF9540)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Règle comptable : le dépôt de garantie est une consignation hors chiffre d\'affaires.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _jourPaiementCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jour limite de paiement',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      suffixText: 'du mois',
                    ),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1 || n > 31) return 'Entre 1 et 31';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<TermePaiementType>(
                    isExpanded: true,
                    initialValue: _termeType,
                    decoration: const InputDecoration(
                      labelText: 'Exigibilité du terme',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: TermePaiementType.aEchoir,
                        child: Text('À échoir (d\'avance)', style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: TermePaiementType.echu,
                        child: Text('Échu (à terme)', style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    selectedItemBuilder: (_) => const [
                      Text('À échoir', style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                      Text('Échu', style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _termeType = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. SIGNATURES & VALIDATION JURIDIQUE
            const Text(
              '5. SIGNATURES & CLAUSES PARTICULIÈRES',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Signé Bailleur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    value: _signeBailleur,
                    onChanged: (val) => setState(() => _signeBailleur = val ?? false),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Signé Locataire', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    value: _signeLocataire,
                    onChanged: (val) => setState(() => _signeLocataire = val ?? false),
                  ),
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _selectionnerDateSignature,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date de signature',
                  prefixIcon: const Icon(Icons.draw_rounded, size: 18),
                  suffixIcon: _dateSignature != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _dateSignature = null),
                        )
                      : null,
                ),
                child: Text(
                  _dateSignature != null
                      ? '${_dateSignature!.day.toString().padLeft(2, '0')}/${_dateSignature!.month.toString().padLeft(2, '0')}/${_dateSignature!.year}'
                      : 'Non renseignée',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _dateSignature != null ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clausesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Clauses et conditions particulières',
                alignLabelWithHint: true,
                hintText: 'Modalités d\'entretien, état des lieux, tolérance animaux...',
              ),
            ),
            const SizedBox(height: 32),

            // Bouton de validation
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _chargement ? null : _sauvegarder,
                child: _chargement
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        estModif ? 'Mettre à jour le Contrat' : 'Créer et Enregistrer le Contrat',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
