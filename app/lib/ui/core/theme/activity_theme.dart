import 'package:flutter/material.dart';

abstract final class ActivityColors {
  static const canvas = Color(0xFFF8FAF6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF3F4F0);
  static const surfaceStrong = Color(0xFFE7E9E5);
  static const ink = Color(0xFF191C1A);
  static const mutedInk = Color(0xFF414943);
  static const outline = Color(0xFFC1C9C1);
  static const primary = Color(0xFF15422E);
  static const primaryContainer = Color(0xFF2E5A44);
  static const primarySoft = Color(0xFFBDEED0);
  static const secondary = Color(0xFF994703);
  static const secondarySoft = Color(0xFFFFDBC9);
  static const error = Color(0xFFBA1A1A);
}

abstract final class ActivitySpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 40.0;
}

abstract final class ActivityTheme {
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: ActivityColors.primary,
      onPrimary: Colors.white,
      primaryContainer: ActivityColors.primaryContainer,
      onPrimaryContainer: Color(0xFFA0CFB4),
      secondary: ActivityColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: ActivityColors.secondarySoft,
      onSecondaryContainer: Color(0xFF6D3000),
      error: ActivityColors.error,
      onError: Colors.white,
      surface: ActivityColors.surface,
      onSurface: ActivityColors.ink,
      surfaceContainerHighest: ActivityColors.surfaceStrong,
      outline: ActivityColors.outline,
    );
    final textTheme = ThemeData.light().textTheme.copyWith(
      displayLarge: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['serif'],
        fontSize: 44,
        height: 52 / 44,
        letterSpacing: -0.88,
        color: ActivityColors.ink,
      ),
      headlineLarge: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['serif'],
        fontSize: 32,
        height: 40 / 32,
        letterSpacing: -0.32,
        color: ActivityColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['serif'],
        fontSize: 26,
        height: 34 / 26,
        letterSpacing: -0.26,
        color: ActivityColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontFamily: 'Georgia',
        fontFamilyFallback: ['serif'],
        fontSize: 20,
        height: 28 / 20,
        color: ActivityColors.ink,
      ),
      bodyLarge: const TextStyle(fontSize: 18, height: 28 / 18),
      bodyMedium: const TextStyle(fontSize: 15, height: 24 / 15),
      bodySmall: const TextStyle(fontSize: 13, height: 20 / 13),
      labelLarge: const TextStyle(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: const TextStyle(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: ActivityColors.canvas,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: ActivityColors.canvas,
        foregroundColor: ActivityColors.ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: ActivityColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: ActivityColors.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: ActivityColors.surfaceMuted,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ActivityColors.primaryContainer,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ActivityColors.surface,
        indicatorColor: Color(0x1F2E5A44),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      ),
    );
  }
}
