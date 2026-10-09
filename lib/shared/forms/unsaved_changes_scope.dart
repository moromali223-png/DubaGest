import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Scope de protection contre la fermeture accidentelle d'un formulaire contenant des modifications non enregistrées.
/// Intercepte le bouton retour Android, la flèche retour de l'AppBar et le retour du navigateur.
class UnsavedChangesScope extends StatelessWidget {
  const UnsavedChangesScope({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.onSaveAndExit,
    this.title = 'Quitter sans enregistrer ?',
    this.message = 'Vous avez des modifications non enregistrées qui seront perdues si vous quittez maintenant.',
    this.stayLabel = 'Continuer la saisie',
    this.exitLabel = 'Quitter',
    this.saveLabel = 'Enregistrer',
  });

  /// Indique si l'utilisateur a modifié au moins un champ du formulaire
  final bool hasUnsavedChanges;

  final Widget child;

  /// Action optionnelle si l'utilisateur choisit d'enregistrer avant de quitter
  final Future<bool> Function()? onSaveAndExit;

  final String title;
  final String message;
  final String stayLabel;
  final String exitLabel;
  final String saveLabel;

  /// Affiche la boîte de dialogue de confirmation de sortie
  static Future<bool> confirmDiscard(
    BuildContext context, {
    String title = 'Quitter sans enregistrer ?',
    String message = 'Vous avez des modifications non enregistrées qui seront perdues si vous quittez maintenant.',
    String stayLabel = 'Continuer la saisie',
    String exitLabel = 'Quitter',
    String saveLabel = 'Enregistrer',
    Future<bool> Function()? onSaveAndExit,
  }) async {
    final result = await showDialog<_DiscardChoice>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.ink, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          // Bouton Continuer la saisie
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, _DiscardChoice.stay),
            child: Text(stayLabel),
          ),
          // Bouton Enregistrer si disponible
          if (onSaveAndExit != null)
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(dialogCtx, _DiscardChoice.saveAndExit),
              child: Text(saveLabel),
            ),
          // Bouton Quitter (rouge)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(dialogCtx, _DiscardChoice.exit),
            child: Text(exitLabel),
          ),
        ],
      ),
    );

    if (result == null || result == _DiscardChoice.stay) {
      return false;
    }

    if (result == _DiscardChoice.saveAndExit && onSaveAndExit != null) {
      return await onSaveAndExit();
    }

    return result == _DiscardChoice.exit;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await confirmDiscard(
          context,
          title: title,
          message: message,
          stayLabel: stayLabel,
          exitLabel: exitLabel,
          saveLabel: saveLabel,
          onSaveAndExit: onSaveAndExit,
        );
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: child,
    );
  }
}

enum _DiscardChoice { stay, exit, saveAndExit }
