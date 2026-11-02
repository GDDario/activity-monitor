import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_colors.dart';

abstract final class ActivityTheme {
  static ThemeData light() {
    final colorScheme = const ColorScheme.light(
      primary: ActivityColors.primary,
      onPrimary: Colors.white,
      primaryContainer: ActivityColors.primaryContainer,
      onPrimaryContainer: ActivityColors.onPrimaryContainer,
      secondary: ActivityColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: ActivityColors.secondarySoft,
      onSecondaryContainer: ActivityColors.onSecondaryContainer,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ActivityColors.primary,
          disabledForegroundColor: ActivityColors.mutedInk.withValues(
            alpha: 0.38,
          ),
          iconSize: 20,
          minimumSize: const Size(48, 48),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: ActivityColors.surface,
        indicatorColor: ActivityColors.navigationIndicator,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      ),
    );
  }
}
