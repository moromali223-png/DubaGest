import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

/// Barre d'actions fixe en bas de formulaire (Sticky Footer).
/// Optimisée pour le pouce sur mobile, avec largeur contrainte sur tablette/desktop.
class StickyFormActions extends StatelessWidget {
  const StickyFormActions({
    super.key,
    required this.onSubmit,
    this.onCancel,
    this.onPrevious,
    this.submitLabel = 'Enregistrer',
    this.cancelLabel = 'Annuler',
    this.previousLabel = 'Précédent',
    this.submitIcon = Icons.check_rounded,
    this.isLoading = false,
    this.isSubmitDisabled = false,
    this.submitKey,
    this.summaryWidget,
    this.leadingAction,
    this.trailingAction,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  /// Action de validation principale (ex: Enregistrer, Valider)
  final VoidCallback? onSubmit;

  /// Action d'annulation (fermer le formulaire)
  final VoidCallback? onCancel;

  /// Action pour revenir à l'étape précédente (mode wizard)
  final VoidCallback? onPrevious;

  final String submitLabel;
  final String cancelLabel;
  final String previousLabel;
  final IconData submitIcon;

  final bool isLoading;
  final bool isSubmitDisabled;
  final Key? submitKey;

  /// Widget de résumé contextuel (ex: total du panier, statut, compteur)
  final Widget? summaryWidget;

  /// Action additionnelle à gauche (ex: supprimer, options)
  final Widget? leadingAction;

  /// Action additionnelle à droite
  final Widget? trailingAction;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (summaryWidget != null) ...[
                    summaryWidget!,
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      // Action gauche : Précédent ou Annuler
                      if (onPrevious != null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: isLoading ? null : onPrevious,
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(previousLabel),
                        )
                      else if (onCancel != null)
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onPressed: isLoading ? null : onCancel,
                          child: Text(cancelLabel),
                        ),

                      if (leadingAction != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        leadingAction!,
                      ],

                      const SizedBox(width: AppSpacing.md),

                      // Action droite principale (Enregistrer / Valider)
                      Expanded(
                        child: FilledButton.icon(
                          key: submitKey,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: (isLoading || isSubmitDisabled || onSubmit == null) ? null : onSubmit,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(submitIcon, size: 20),
                          label: Text(
                            submitLabel,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),

                      if (trailingAction != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        trailingAction!,
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
