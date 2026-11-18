import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/theme/activity_palette.dart';

void main() {
  test(
    'dark semantic palette keeps primary text and action pairs readable',
    () {
      final theme = ActivityTheme.dark(),
          p = theme.extension<ActivityPalette>()!;
      double contrast(Color a, Color b) {
        final x = a.computeLuminance(), y = b.computeLuminance();
        return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
      }

      expect(theme.brightness, Brightness.dark);
      for (final pair in [
        (p.ink, p.surface),
        (p.mutedInk, p.canvas),
        (p.onPrimary, p.primary),
        (p.onContainerAction, p.primaryContainer),
        (p.badgeInk, p.selectedBadge),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      expect(
        contrast(theme.colorScheme.onError, theme.colorScheme.error),
        greaterThanOrEqualTo(4.5),
      );
      expect(p.canvas, isNot(Colors.white));
    },
  );
}
