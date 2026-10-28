import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Logo DubaGest adaptatif avec support multi-écrans, gestion claire/sombre et assets robustes.
class DubaGestBrandLogo extends StatelessWidget {
  const DubaGestBrandLogo({
    super.key,
    this.size = 56,
    this.showText = false,
    this.subtitle,
    this.isLight = false,
    this.vertical = false,
  });

  final double size;
  final bool showText;
  final String? subtitle;
  final bool isLight;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;
    final onDarkBackground = isLight || isDarkTheme;

    final logoWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDarkTheme
            ? theme.colorScheme.surfaceContainerHigh
            : (isLight ? Colors.white : AppColors.surface),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: onDarkBackground ? 0.25 : 0.12),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.12),
          ),
        ],
        border: Border.all(
          color: isDarkTheme
              ? theme.colorScheme.outlineVariant
              : (isLight ? Colors.white.withValues(alpha: 0.3) : AppColors.border),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          'assets/icons/app_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _FallbackIcon(size: size),
        ),
      ),
    );

    if (!showText) return logoWidget;

    final titleColor = isDarkTheme
        ? theme.colorScheme.onSurface
        : (isLight ? Colors.white : AppColors.ink);

    final subtitleColor = isDarkTheme
        ? theme.colorScheme.onSurfaceVariant
        : (isLight ? Colors.white.withValues(alpha: 0.85) : AppColors.muted);

    final textContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'DubaGest',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: titleColor,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            textAlign: vertical ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: (size * 0.24).clamp(11.0, 14.0),
              fontWeight: FontWeight.w600,
              color: subtitleColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ],
    );

    if (vertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          logoWidget,
          const SizedBox(height: 12),
          textContent,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoWidget,
        const SizedBox(width: 14),
        Flexible(child: textContent),
      ],
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.green, AppColors.greenPressed],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.trending_up_rounded,
          color: Colors.white,
          size: size * 0.55,
        ),
      ),
    );
  }
}
