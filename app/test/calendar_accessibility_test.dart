import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';

void main() {
  for (final locale in [const Locale('en', 'US'), const Locale('pt', 'BR')]) {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'calendar controls have accessible labels and targets in $locale at $width',
        (tester) async {
          final semantics = tester.ensureSemantics();
          await tester.binding.setSurfaceSize(Size(width, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                calendarDataProvider.overrideWith(
                  (ref) async => const CalendarData([], []),
                ),
              ],
              child: MaterialApp(
                locale: locale,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('pt', 'BR'),
                ],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: const CalendarView(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          semantics.dispose();
        },
      );
    }
  }

  testWidgets('narrow grid reveals selected dates at both edges', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final model = CalendarViewModel(
      DateTime(2024, 1, 6),
      () async => const CalendarData([], []),
    );
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarViewModelProvider.overrideWith((ref) => model)],
        child: const MaterialApp(home: CalendarView()),
      ),
    );
    await tester.pumpAndSettle();
    Finder selected() => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.selected == true &&
          (widget.properties.label?.contains('2024') ?? false),
    );
    void expectSelectedInsideCard() {
      final selectedRect = tester.getRect(selected());
      final cardRect = tester.getRect(find.byType(Card).first);
      expect(selectedRect.width, greaterThanOrEqualTo(48));
      expect(selectedRect.left, greaterThanOrEqualTo(cardRect.left));
      expect(selectedRect.right, lessThanOrEqualTo(cardRect.right));
    }

    expectSelectedInsideCard();
    model.selectDate(DateTime(2024, 1, 7));
    await tester.pumpAndSettle();
    expectSelectedInsideCard();
  });
}
