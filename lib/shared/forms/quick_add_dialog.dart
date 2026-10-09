import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Boîte de dialogue compacte pour l'ajout express d'une entité
/// (ex: client rapide, catégorie rapide, fournisseur rapide).
class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({
    super.key,
    required this.title,
    required this.primaryLabel,
    this.primaryHint,
    this.primaryIcon = Icons.edit_rounded,
    this.primaryCapitalization = TextCapitalization.words,
    this.secondaryLabel,
    this.secondaryHint,
    this.secondaryIcon = Icons.phone_outlined,
    this.secondaryKeyboardType = TextInputType.text,
    this.saveLabel = 'Ajouter',
    this.cancelLabel = 'Annuler',
    this.initialPrimaryText,
    this.initialSecondaryText,
  });

  final String title;
  final String primaryLabel;
  final String? primaryHint;
  final IconData primaryIcon;
  final TextCapitalization primaryCapitalization;

  final String? secondaryLabel;
  final String? secondaryHint;
  final IconData secondaryIcon;
  final TextInputType secondaryKeyboardType;

  final String saveLabel;
  final String cancelLabel;

  final String? initialPrimaryText;
  final String? initialSecondaryText;

  /// Affiche le dialogue et retourne le couple (nom, informationSecondaire).
  static Future<(String primary, String? secondary)?> show(
    BuildContext context, {
    required String title,
    required String primaryLabel,
    String? primaryHint,
    IconData primaryIcon = Icons.edit_rounded,
    TextCapitalization primaryCapitalization = TextCapitalization.words,
    String? secondaryLabel,
    String? secondaryHint,
    IconData secondaryIcon = Icons.phone_outlined,
    TextInputType secondaryKeyboardType = TextInputType.text,
    String saveLabel = 'Ajouter',
    String cancelLabel = 'Annuler',
    String? initialPrimaryText,
    String? initialSecondaryText,
  }) {
    return showDialog<(String, String?)>(
      context: context,
      builder: (_) => QuickAddDialog(
        title: title,
        primaryLabel: primaryLabel,
        primaryHint: primaryHint,
        primaryIcon: primaryIcon,
        primaryCapitalization: primaryCapitalization,
        secondaryLabel: secondaryLabel,
        secondaryHint: secondaryHint,
        secondaryIcon: secondaryIcon,
        secondaryKeyboardType: secondaryKeyboardType,
        saveLabel: saveLabel,
        cancelLabel: cancelLabel,
        initialPrimaryText: initialPrimaryText,
        initialSecondaryText: initialSecondaryText,
      ),
    );
  }

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  late final TextEditingController _primary = TextEditingController(text: widget.initialPrimaryText);
  late final TextEditingController _secondary = TextEditingController(text: widget.initialSecondaryText);

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    super.dispose();
  }

  void _submit() {
    final p = _primary.text.trim();
    if (p.isEmpty) return;
    final s = _secondary.text.trim();
    Navigator.pop(context, (p, s.isEmpty ? null : s));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _primary.text.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.greenSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.flash_on_rounded, color: AppColors.green, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _primary,
              autofocus: true,
              textCapitalization: widget.primaryCapitalization,
              textInputAction: widget.secondaryLabel != null ? TextInputAction.next : TextInputAction.done,
              decoration: InputDecoration(
                labelText: '${widget.primaryLabel} *',
                hintText: widget.primaryHint,
                prefixIcon: Icon(widget.primaryIcon),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (widget.secondaryLabel == null) _submit();
              },
            ),
            if (widget.secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _secondary,
                keyboardType: widget.secondaryKeyboardType,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: widget.secondaryLabel,
                  hintText: widget.secondaryHint,
                  prefixIcon: Icon(widget.secondaryIcon),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF01226C),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: canSubmit ? _submit : null,
          child: Text(widget.saveLabel),
        ),
      ],
    );
  }
}
