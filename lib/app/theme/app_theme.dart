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
  // Couleur primaire et identité DubaGest (Vert Émeraude #1E7E4E & Ardoise #1A2522)
  static const green = Color(0xFF1E7E4E);
  static const greenPressed = Color(0xFF15633D);
  static const greenLight = Color(0xFF27AE60);
  static const greenSoft = Color(0xFFE8F5EE);
  static const greenOnDark = Color(0xFF2ECC71);

  static const primary = green;
  static const primaryDark = greenPressed;
  static const primaryLight = greenLight;
  static const primarySoft = greenSoft;

  // Alias rétrocompatibilité
  static const navy = green;
  static const navyDark = greenPressed;
  static const navyLight = greenLight;
  static const navySoft = greenSoft;

  static const gold = Color(0xFFD97706);
  static const goldDark = Color(0xFFB45309);
  static const goldLight = Color(0xFFF59E0B);
  static const goldSoft = Color(0xFFFDECDA);

  // Ardoise sombre / surfaces (Mode Clair)
  static const ink = Color(0xFF1A2522);
  static const inkRaised = Color(0xFF243631);
  static const inkBorder = Color(0xFF334A43);
  static const onInkMuted = Color(0xFFA5B8B1);
  static const background = Color(0xFFF4F7F5);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const muted = Color(0xFF64748B);

  // Surfaces Sombre (Mode Nuit DubaGest)
  static const darkBackground = Color(0xFF0F1714);
  static const darkSurface = Color(0xFF182420);
  static const darkSurfaceRaised = Color(0xFF20302B);
  static const darkBorder = Color(0xFF2A3D37);
  static const darkOnSurface = Color(0xFFF1F5F3);
  static const darkOnSurfaceMuted = Color(0xFFA5B8B1);

  // Sens (données financières)
  static const positive = Color(0xFF1E7E4E);
  static const positiveSoft = Color(0xFFE8F5EE);
  static const negative = Color(0xFFEF4444);
  static const negativeSoft = Color(0xFFFEF2F2);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFDECDA);

  // Sémantique Dettes & Créances
  static const creance = Color(0xFF1E7E4E); // Vert Émeraude : À recevoir (argent entrant)
  static const creanceSoft = Color(0xFFE8F5EE);
  static const dette = Color(0xFFEA580C); // Ambre / Orange chaud : À payer / Dette fournisseur
  static const detteSoft = Color(0xFFFFF7ED);
  static const detteHeader = Color(0xFFC2410C); // Terracotta soutenu pour bandeau de synthèse dette
  static const avoir = Color(0xFFDC2626); // Rouge note d'avoir / crédit à déduire
  static const avoirSoft = Color(0xFFFEF2F2);
}

/// Thème Material 3 DubaGest. L'identité visuelle se configure ici.
abstract final class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      onPrimary: Colors.white,
      primaryContainer: AppColors.greenSoft,
      onPrimaryContainer: AppColors.greenPressed,
      secondary: AppColors.ink,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.greenSoft,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.gold,
      error: AppColors.negative,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.muted,
      outlineVariant: AppColors.border,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.background,
      surfaceContainerHigh: const Color(0xFFF1F5F3),
      surfaceContainerHighest: const Color(0xFFE8ECE9),
    );
    return _build(scheme, AppColors.background);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.dark,
      primary: AppColors.greenOnDark, // Vert Émeraude vibrant et lisible sur sombre (#2ECC71)
      onPrimary: const Color(0xFF042013),
      primaryContainer: const Color(0xFF154430),
      onPrimaryContainer: const Color(0xFFA7F3D0),
      secondary: const Color(0xFF86EFAC),
      onSecondary: const Color(0xFF052E16),
      secondaryContainer: const Color(0xFF1E382E),
      onSecondaryContainer: const Color(0xFFD1FAE5),
      tertiary: AppColors.goldLight,
      error: const Color(0xFFF87171),
      onError: const Color(0xFF450A0A),
      errorContainer: const Color(0xFF4C1D1D),
      onErrorContainer: const Color(0xFFFECACA),
      surface: AppColors.darkSurface, // Ardoise foncée #182420
      onSurface: AppColors.darkOnSurface, // Lisibilité optimale #F1F5F3
      onSurfaceVariant: AppColors.darkOnSurfaceMuted, // #A5B8B1
      outline: const Color(0xFF3B524A),
      outlineVariant: AppColors.darkBorder, // #2A3D37
      surfaceContainerLowest: const Color(0xFF0A100E),
      surfaceContainerLow: const Color(0xFF0F1714),
      surfaceContainer: AppColors.darkSurface,
      surfaceContainerHigh: AppColors.darkSurfaceRaised, // #20302B (champs de saisie)
      surfaceContainerHighest: const Color(0xFF283B35),
    );
    return _build(scheme, AppColors.darkBackground);
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final isDark = scheme.brightness == Brightness.dark;
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
        fillColor: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(color: scheme.primary, fontSize: 13, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 14),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        errorStyle: TextStyle(color: scheme.error, fontSize: 12, fontWeight: FontWeight.w600),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: scheme.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, 48),
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
          selectedBackgroundColor: isDark ? scheme.primaryContainer : AppColors.ink,
          selectedForegroundColor: isDark ? scheme.onPrimaryContainer : Colors.white,
          minimumSize: const Size(0, 44),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : AppColors.ink,
        contentTextStyle: TextStyle(color: isDark ? scheme.onSurface : Colors.white),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? scheme.surface : AppColors.ink,
        width: 312,
      ),
    );
  }
}
