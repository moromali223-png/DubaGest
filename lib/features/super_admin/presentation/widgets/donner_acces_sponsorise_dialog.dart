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
  String _planSelectionne = 'MOYEN';
  bool _enCours = false;

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

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enCours = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      await repo.accorderAccesSponsorise(
        entrepriseId: widget.entrepriseId,
        planCode: _planSelectionne,
        motif: _motifCtrl.text.trim(),
      );
      if (mounted) {
        ref.invalidate(superAdminDashboardProvider);
        ref.invalidate(superAdminEntreprisesProvider);
        ref.invalidate(superAdminDetailEntrepriseProvider(widget.entrepriseId));
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.green,
            content: Text(
              'Accès sponsorisé ($_planSelectionne) accordé avec succès à ${widget.entrepriseNom} !',
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
            child: const Icon(Icons.stars_rounded, color: Color(0xFF7C3AED), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Accorder un accès sponsorisé',
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Entreprise bénéficiaire :', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(widget.entrepriseNom, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Formule de référence accordée :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in [
                    {'code': 'NORMAL', 'nom': 'Normal (1 000 F)', 'color': const Color(0xFF2563EB)},
                    {'code': 'MOYEN', 'nom': 'Moyen (2 000 F)', 'color': const Color(0xFF7C3AED)},
                    {'code': 'PRO', 'nom': 'Pro (5 000 F)', 'color': const Color(0xFFEA580C)},
                  ])
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Montant facturé à l\'entreprise : 0 FCFA\nDurée : Indéterminée (valable jusqu\'à révocation).',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _motifCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Motif officiel de la gratuité / sponsor *',
                  hintText: 'Ex: Partenariat pilote, Accord d\'incubateur, Client VIP...',
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
                    return 'Veuillez justifier précisément le motif (min 4 caractères).';
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
          label: const Text('Valider le sponsor', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
