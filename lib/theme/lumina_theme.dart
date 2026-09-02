import 'package:flutter/material.dart';

/// Paleta y estilo "Lumina Finance" según `mock/lumina_finance/DESIGN.md`.
class LuminaColors {
  LuminaColors._();

  // Superficies (off-white cálido)
  static const surface = Color(0xFFF9F9F8);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainer = Color(0xFFEEEEED);
  static const surfaceContainerHigh = Color(0xFFE8E8E7);
  static const surfaceContainerHighest = Color(0xFFE2E2E2);

  // Tinta
  static const onSurface = Color(0xFF1A1C1C);
  static const onSurfaceVariant = Color(0xFF49454E);
  static const outline = Color(0xFF7A757F);
  static const outlineVariant = Color(0xFFCBC4CF);
  static const inverseSurface = Color(0xFF2F3130);
  static const inverseOnSurface = Color(0xFFF1F1F0);

  // Primario: violeta profundo elegante
  static const primary = Color(0xFF352553);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF4C3B6B);
  static const onPrimaryContainer = Color(0xFFBCA7DF);
  static const primaryFixedDim = Color(0xFFD2BDF6);

  // Secundario: lavanda suave
  static const secondary = Color(0xFF5F5D69);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFE5E0EF);
  static const onSecondaryContainer = Color(0xFF65636F);
  static const secondaryFixedDim = Color(0xFFC9C4D3);

  // Terciario: dorado cálido
  static const tertiary = Color(0xFF735C00);
  static const onTertiary = Color(0xFFFFFFFF);
  static const tertiaryContainer = Color(0xFFCCA72F);
  static const tertiaryFixedDim = Color(0xFFE9C349);
  static const onTertiaryFixed = Color(0xFF241A00);

  // Errores
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  // Acentos para tendencias
  static const positive = Color(0xFF1E8E3E);
  static const negative = Color(0xFFF08080);
  static const warmGold = Color(0xFFD4AF37);

  // Card divider sutil (primary al 5%)
  static const cardBorder = Color(0x0D352553);
}

class LuminaRadii {
  LuminaRadii._();

  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const card = 24.0;
  static const pill = 999.0;
}

ThemeData luminaTheme() {
  const scheme = ColorScheme.light(
    primary: LuminaColors.primary,
    onPrimary: LuminaColors.onPrimary,
    primaryContainer: LuminaColors.primaryContainer,
    onPrimaryContainer: LuminaColors.onPrimaryContainer,
    secondary: LuminaColors.secondary,
    onSecondary: LuminaColors.onSecondary,
    secondaryContainer: LuminaColors.secondaryContainer,
    onSecondaryContainer: LuminaColors.onSecondaryContainer,
    tertiary: LuminaColors.tertiary,
    onTertiary: LuminaColors.onTertiary,
    tertiaryContainer: LuminaColors.tertiaryContainer,
    error: LuminaColors.error,
    onError: LuminaColors.onError,
    errorContainer: LuminaColors.errorContainer,
    onErrorContainer: LuminaColors.onErrorContainer,
    surface: LuminaColors.surface,
    onSurface: LuminaColors.onSurface,
    onSurfaceVariant: LuminaColors.onSurfaceVariant,
    outline: LuminaColors.outline,
    outlineVariant: LuminaColors.outlineVariant,
    surfaceContainerLowest: LuminaColors.surfaceContainerLowest,
    surfaceContainer: LuminaColors.surfaceContainer,
    surfaceContainerHigh: LuminaColors.surfaceContainerHigh,
    surfaceContainerHighest: LuminaColors.surfaceContainerHighest,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LuminaColors.surface,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 40,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: LuminaColors.onSurface,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: LuminaColors.onSurface,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: LuminaColors.onSurface,
      ),
      titleLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: LuminaColors.onSurface,
      ),
      titleMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: LuminaColors.onSurface,
      ),
      bodyLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: LuminaColors.onSurface,
      ),
      bodyMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: LuminaColors.onSurface,
      ),
      bodySmall: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: LuminaColors.onSurfaceVariant,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: LuminaColors.onSurface,
      ),
      labelMedium: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: LuminaColors.onSurfaceVariant,
      ),
      labelSmall: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: LuminaColors.onSurfaceVariant,
      ),
    ),
    cardTheme: CardThemeData(
      color: LuminaColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.card),
        side: const BorderSide(color: LuminaColors.cardBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LuminaColors.primary,
        foregroundColor: LuminaColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminaRadii.xl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LuminaColors.primary,
        side: const BorderSide(color: LuminaColors.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminaRadii.xl),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: LuminaColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LuminaRadii.lg),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LuminaColors.secondaryContainer.withValues(alpha: 0.3),
      hintStyle: const TextStyle(color: LuminaColors.onSurfaceVariant),
      labelStyle: const TextStyle(color: LuminaColors.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.xl),
        borderSide: const BorderSide(color: LuminaColors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.xl),
        borderSide: const BorderSide(color: LuminaColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.xl),
        borderSide: const BorderSide(color: LuminaColors.primary, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LuminaColors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.card),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: LuminaColors.onSurface,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: LuminaColors.inverseOnSurface,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LuminaRadii.lg),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LuminaColors.surface,
      foregroundColor: LuminaColors.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: LuminaColors.onSurface,
      ),
    ),
  );
}
