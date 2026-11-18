import 'package:flutter/material.dart';

import 'package:app/ui/core/theme/activity_palette.dart';

abstract final class ActivityTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);
  static ThemeData _build(bool dark) {
    final palette = ActivityPalette(dark: dark);
    final colorScheme =
        (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          primaryContainer: palette.primaryContainer,
          onPrimaryContainer: palette.onPrimaryContainer,
          secondary: palette.secondary,
          onSecondary: dark ? const Color(0xff321200) : Colors.white,
          secondaryContainer: palette.secondarySoft,
          onSecondaryContainer: palette.onSecondaryContainer,
          error: palette.error,
          onError: dark ? const Color(0xff601410) : Colors.white,
          surface: palette.surface,
          surfaceContainerLowest: palette.canvas,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceMuted,
          surfaceDim: palette.surface,
          surfaceBright: palette.surfaceStrong,
          onSurfaceVariant: palette.mutedInk,
          outlineVariant: palette.border,
          onSurface: palette.ink,
          surfaceContainerHighest: palette.surfaceStrong,
          outline: palette.outline,
        );
    final textTheme = (dark ? ThemeData.dark() : ThemeData.light()).textTheme
        .copyWith(
          displayLarge: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontSize: 44,
            height: 52 / 44,
            letterSpacing: -0.88,
            color: palette.ink,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontSize: 32,
            height: 40 / 32,
            letterSpacing: -0.32,
            color: palette.ink,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontSize: 26,
            height: 34 / 26,
            letterSpacing: -0.26,
            color: palette.ink,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Georgia',
            fontFamilyFallback: const ['serif'],
            fontSize: 20,
            height: 28 / 20,
            color: palette.ink,
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
      brightness: dark ? Brightness.dark : Brightness.light,
      extensions: [palette],
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.inputSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: palette.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelMedium?.copyWith(color: palette.ink),
        selectedColor: palette.primary,
        checkmarkColor: palette.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.primaryContainer,
          foregroundColor: palette.onContainerAction,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: palette.primary,
          disabledForegroundColor: palette.mutedInk.withValues(alpha: 0.38),
          iconSize: 20,
          minimumSize: const Size(48, 48),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.navigationIndicator,
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      ),
    );
  }
}
