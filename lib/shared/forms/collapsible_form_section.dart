import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';
import 'form_section_status.dart';

/// Section de formulaire intelligente et repliable.
/// Affiche un résumé dynamique lorsqu'elle est fermée et un indicateur de complétion.
class CollapsibleFormSection extends StatefulWidget {
  const CollapsibleFormSection({
    super.key,
    required this.title,
    this.icon,
    this.summary,
    this.status = FormSectionStatus.emptyOptional,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.isRequired = false,
    this.errorText,
    this.headerTrailing,
    this.badge,
    this.accentColor,
  });

  final String title;
  final IconData? icon;

  /// Résumé automatique affiché lorsque la section est fermée
  final String? summary;

  /// Indicateur d'état (complète, partielle, erreur, facultative, obligatoire)
  final FormSectionStatus status;

  /// État d'ouverture
  final bool isExpanded;

  /// Callback lors du clic sur l'en-tête
  final VoidCallback onToggle;

  /// Contenu des champs du formulaire
  final Widget child;

  /// Indique si la section est obligatoire (affiche une astérisque *)
  final bool isRequired;

  /// Message d'erreur éventuel lié à cette section
  final String? errorText;

  /// Widget additionnel à droite dans l'en-tête (ex: compteur, action rapide)
  final Widget? headerTrailing;

  /// Badge optionnel (ex: "Étape 1", "Facultatif", "Nouveau")
  final String? badge;

  /// Couleur d'accentuation optionnelle pour l'icône
  final Color? accentColor;

  @override
  State<CollapsibleFormSection> createState() => _CollapsibleFormSectionState();
}

class _CollapsibleFormSectionState extends State<CollapsibleFormSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _chevronRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
      value: widget.isExpanded ? 1.0 : 0.0,
    );
    _chevronRotation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant CollapsibleFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null || widget.status == FormSectionStatus.error;
    final color = widget.accentColor ?? const Color(0xFF01226C);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? AppColors.negative.withValues(alpha: 0.5)
              : widget.isExpanded
                  ? color.withValues(alpha: 0.3)
                  : AppColors.border,
          width: hasError || widget.isExpanded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isExpanded
                ? color.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: widget.isExpanded ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header tactile avec grande zone de clic (min 56px)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                  child: Row(
                    children: [
                      // Icône thématique
                      if (widget.icon != null) ...[
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: widget.isExpanded
                                ? color.withValues(alpha: 0.1)
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            widget.icon,
                            size: 20,
                            color: widget.isExpanded ? color : AppColors.ink,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],

                      // Titre, Astérisque et Résumé automatique
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: widget.isExpanded ? FontWeight.w700 : FontWeight.w600,
                                      color: hasError ? AppColors.negative : AppColors.ink,
                                    ),
                                  ),
                                ),
                                if (widget.isRequired) ...[
                                  const SizedBox(width: 4),
                                  const Text(
                                    '*',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.negative,
                                    ),
                                  ),
                                ],
                                if (widget.badge != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      widget.badge!,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            // Résumé visible lorsque la section est fermée
                            if (!widget.isExpanded && widget.summary != null && widget.summary!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                widget.summary!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: AppSpacing.sm),

                      if (widget.headerTrailing != null) ...[
                        widget.headerTrailing!,
                        const SizedBox(width: AppSpacing.xs),
                      ],

                      // Indicateur de statut
                      _StatusIndicatorBadge(status: widget.status),
                      const SizedBox(width: 8),

                      // Chevron animé
                      RotationTransition(
                        turns: _chevronRotation,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Message d'erreur de la section
            if (widget.errorText != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.negative.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.negative),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.errorText!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.negative,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Contenu dépliable avec animation fluide
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: widget.isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: widget.child,
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicatorBadge extends StatelessWidget {
  const _StatusIndicatorBadge({required this.status});

  final FormSectionStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == FormSectionStatus.emptyOptional) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Facultatif',
          style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w500),
        ),
      );
    }

    if (status == FormSectionStatus.complete) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.positive.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 14,
          color: AppColors.positive,
        ),
      );
    }

    if (status == FormSectionStatus.error || status == FormSectionStatus.emptyRequired) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.negative.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.priority_high_rounded,
          size: 14,
          color: AppColors.negative,
        ),
      );
    }

    if (status == FormSectionStatus.partial) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
