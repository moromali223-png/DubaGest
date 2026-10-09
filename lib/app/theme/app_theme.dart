import 'package:flutter/material.dart';

/// Espacements (grille de 4) — à utiliser plutôt que des valeurs en dur.
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Points de rupture Material 3 (largeur de fenêtre).
abstract final class AppBreakpoints {
  static const medium = 600.0;
  static const expanded = 840.0;

  /// Largeur maximale de lecture pour formulaires et listes sur grand écran.
  static const contentMaxWidth = 720.0;
}

/// Palette DubaGest : Vert Émeraude (#1E7E4E) + Ardoise Sombre (#1A2522) + Menthe douce (#E8F5EE).
abstract final class AppColors {
  // Couleur primaire et identité
  static const green = Color(0xFF1E7E4E);
  static const greenPressed = Color(0xFF15633D);
  static const greenLight = Color(0xFF27AE60);
  static const greenSoft = Color(0xFFE8F5EE);
  static const greenOnDark = Color(0xFF2ECC71);

  // Alias institutionnels
  static const navy = Color(0xFF1E7E4E);
  static const navyDark = Color(0xFF15633D);
  static const navyLight = Color(0xFF27AE60);
  static const navySoft = Color(0xFFE8F5EE);

  static const gold = Color(0xFFD97706);
  static const goldDark = Color(0xFFB45309);
  static const goldLight = Color(0xFFF59E0B);
  static const goldSoft = Color(0xFFFDECDA);

  // Ardoise sombre / surfaces
  static const ink = Color(0xFF1A2522);
  static const inkRaised = Color(0xFF243631);
  static const inkBorder = Color(0xFF334A43);
  static const onInkMuted = Color(0xFFA5B8B1);
  static const background = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5EAE7);
  static const muted = Color(0xFF64748B);

  // Sens (données financières) — toujours accompagnés d'une flèche ou d'un signe.
  static const positive = Color(0xFF1E7E4E);
  static const positiveSoft = Color(0xFFE8F5EE);
  static const negative = Color(0xFFDC2626);
  static const negativeSoft = Color(0xFFFEE2E2);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFDECDA);
}

/// Thème Material 3. L'identité visuelle se change ici uniquement.
abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      onPrimary: Colors.white,
      primaryContainer: AppColors.navySoft,
      onPrimaryContainer: AppColors.navyDark,
      secondary: AppColors.gold,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.goldSoft,
      onSecondaryContainer: AppColors.goldDark,
      tertiary: AppColors.warning,
      error: AppColors.negative,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.border,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.background,
    );
    return _build(scheme, AppColors.background);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      onPrimary: AppColors.ink,
      surface: const Color(0xFF0F1B2B),
      error: const Color(0xFFF4A99F),
    );
    return _build(scheme, const Color(0xFF0A131E));
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final rounded14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return base.copyWith(
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: rounded14,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: rounded14,
          side: BorderSide(color: scheme.outlineVariant),
          foregroundColor: scheme.onSurface,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.ink,
          selectedForegroundColor: Colors.white,
          minimumSize: const Size(0, 44),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.ink, width: 312),
    );
  }
}
