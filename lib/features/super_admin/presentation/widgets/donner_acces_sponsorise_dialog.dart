import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../providers/super_admin_providers.dart';

class DonnerAccesSponsoriseDialog extends ConsumerStatefulWidget {
  const DonnerAccesSponsoriseDialog({
    super.key,
    required this.entrepriseId,
    required this.entrepriseNom,
    this.planActuel,
  });

  final String entrepriseId;
  final String entrepriseNom;
  final String? planActuel;

  static Future<bool?> show(
    BuildContext context, {
    required String entrepriseId,
    required String entrepriseNom,
    String? planActuel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DonnerAccesSponsoriseDialog(
        entrepriseId: entrepriseId,
        entrepriseNom: entrepriseNom,
        planActuel: planActuel,
      ),
    );
  }

  @override
  ConsumerState<DonnerAccesSponsoriseDialog> createState() => _DonnerAccesSponsoriseDialogState();
}

class _DonnerAccesSponsoriseDialogState extends ConsumerState<DonnerAccesSponsoriseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motifCtrl = TextEditingController();
  String _planSelectionne = 'PRO';
  int? _dureeMois = 1;
  String _typeFacturation = 'COMMERCIAL';
  bool _enCours = false;

  static const _plans = [
    {'code': 'NORMAL', 'nom': 'Normal (1 000 F)', 'prix': 1000, 'color': Color(0xFF2563EB)},
    {'code': 'MOYEN', 'nom': 'Moyen (2 000 F)', 'prix': 2000, 'color': Color(0xFF7C3AED)},
    {'code': 'PRO', 'nom': 'Pro (5 000 F • Microfinance)', 'prix': 5000, 'color': Color(0xFFEA580C)},
  ];

  static const _durees = <(int?, String)>[
    (1, '1 mois'),
    (3, '3 mois'),
    (6, '6 mois'),
    (12, '12 mois (1 an)'),
    (null, 'Illimité (0 F)'),
  ];

  static const _motifsRapides = [
    'Activation Pro par l\'administrateur',
    'Paiement Mobile Money validé',
    'Paiement espèces reçu',
    'Partenaire sponsorisé',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.planActuel != null && ['NORMAL', 'MOYEN', 'PRO'].contains(widget.planActuel)) {
      _planSelectionne = widget.planActuel!;
    }
  }

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  int get _prixMensuel {
    for (final p in _plans) {
      if (p['code'] == _planSelectionne) return p['prix'] as int;
    }
    return 0;
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.accorderAccesSponsorise(
        entrepriseId: widget.entrepriseId,
        planCode: _planSelectionne,
        dureeMois: _dureeMois,
        typeFacturation: _typeFacturation,
        motif: _motifCtrl.text.trim(),
      );
      if (mounted) {
        ref.invalidate(superAdminDashboardProvider);
        ref.invalidate(superAdminEntreprisesProvider);
        ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
        Navigator.of(context).pop(true);
        final dureeTxt = _dureeMois == null ? 'durée illimitée' : '$_dureeMois mois';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green,
            content: Text(
              'Abonnement $_planSelectionne ($dureeTxt) activé avec succès pour ${widget.entrepriseNom} !',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.negative,
            content: Text('Erreur : $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final montantTotal = _typeFacturation == 'SPONSORISE' ? 0 : _prixMensuel * (_dureeMois ?? 1);
    final libelleDuree = _dureeMois == null ? 'Illimitée (jusqu\'à révocation)' : '$_dureeMois mois';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Activer / Modifier l\'abonnement',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entreprise concernée :', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(widget.entrepriseNom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('1. Formule à activer :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _plans)
                    ChoiceChip(
                      label: Text(p['nom'] as String),
                      selected: _planSelectionne == p['code'],
                      selectedColor: (p['color'] as Color).withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _planSelectionne == p['code'] ? (p['color'] as Color) : AppColors.ink,
                      ),
                      onSelected: (sel) {
                        if (sel) setState(() => _planSelectionne = p['code'] as String);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('2. Durée d\'activation :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _durees)
                    ChoiceChip(
                      label: Text(d.$2),
                      selected: _dureeMois == d.$1,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _dureeMois == d.$1 ? AppColors.primary : AppColors.ink,
                      ),
                      onSelected: (sel) {
                        if (!sel) return;
                        setState(() {
                          _dureeMois = d.$1;
                          if (d.$1 == null) {
                            _typeFacturation = 'SPONSORISE';
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('3. Mode de facturation :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Payé / Validé manuellement'),
                    selected: _typeFacturation == 'COMMERCIAL',
                    selectedColor: const Color(0xFF059669).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _typeFacturation == 'COMMERCIAL' ? const Color(0xFF059669) : AppColors.ink,
                    ),
                    onSelected: (sel) {
                      if (!sel) return;
                      setState(() {
                        _typeFacturation = 'COMMERCIAL';
                        _dureeMois ??= 1;
                      });
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Sponsorisé gratuit (0 FCFA)'),
                    selected: _typeFacturation == 'SPONSORISE',
                    selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _typeFacturation == 'SPONSORISE' ? const Color(0xFF7C3AED) : AppColors.ink,
                    ),
                    onSelected: (sel) {
                      if (!sel) return;
                      setState(() => _typeFacturation = 'SPONSORISE');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Formule : $_planSelectionne • Durée : $libelleDuree\n'
                        'Montant de référence : $montantTotal FCFA\n'
                        '${_planSelectionne == 'PRO' ? 'Module Microfinance : ACTIVÉ' : 'Module Microfinance : Non inclus (Pro requis)'}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.35, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('4. Motif d\'audit :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in _motifsRapides)
                    ActionChip(
                      label: Text(m, style: const TextStyle(fontSize: 11)),
                      onPressed: () {
                        setState(() {
                          _motifCtrl.text = m;
                          if (m == 'Partenaire sponsorisé') {
                            _typeFacturation = 'SPONSORISE';
                          } else if (m.startsWith('Paiement')) {
                            _typeFacturation = 'COMMERCIAL';
                            _dureeMois ??= 1;
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _motifCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motif officiel *',
                  hintText: 'Ex: Activation Pro par l\'administrateur, Paiement Mobile Money validé...',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 4) {
                    return 'Veuillez préciser le motif (min 4 caractères).';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enCours ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton.icon(
          onPressed: _enCours ? null : _soumettre,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          icon: _enCours
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Activer l\'abonnement', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
