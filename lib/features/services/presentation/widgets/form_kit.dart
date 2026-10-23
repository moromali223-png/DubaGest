import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

/// Une section numérotée pour guider l'utilisateur dans les étapes du formulaire.
class NumberedSection extends StatelessWidget {
  const NumberedSection({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    required this.child,
    this.done = false,
  });

  final int number;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? AppColors.navy.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done ? AppColors.navy : AppColors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: done ? AppColors.navy : AppColors.border),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text(
                            '$number',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: AppColors.navy,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.navy,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Un petit texte d'aide sous les champs de saisie.
class FieldHint extends StatelessWidget {
  const FieldHint(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 13, color: AppColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
