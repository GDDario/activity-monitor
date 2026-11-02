import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/theme/activity_colors.dart';

void main() {
  testWidgets('places view selector above the calendar card', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getBottomLeft(find.byType(SegmentedButton<bool>)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(Card).first).dy),
    );
  });

  testWidgets('places Today alongside the view selector', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    final today = tester.getCenter(
      find.widgetWithText(OutlinedButton, 'Today'),
    );
    final toggle = tester.getCenter(find.byType(SegmentedButton<bool>));
    expect(today.dy, toggle.dy);
    expect(today.dx, lessThan(toggle.dx));
  });

  testWidgets('Today button includes a sun icon', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    expect(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'Today'),
        matching: find.byIcon(Icons.wb_sunny_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('collaborative legend uses the secondary color', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    final legend = tester.widget<Text>(find.text('◆  Collaborative'));
    expect(legend.style?.color, ActivityColors.secondary);
  });

  testWidgets('uses contrasting selected and muted unselected filter colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('All Cadences'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final selected = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'All Cadences'),
    );
    final unselected = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Daily Habits'),
    );
    expect(selected.selectedColor, ActivityColors.primary);
    expect(selected.labelStyle?.color, Colors.white);
    expect(unselected.backgroundColor, ActivityColors.surfaceMuted);
    expect(unselected.labelStyle?.color, ActivityColors.mutedInk);
  });

  testWidgets('selected date uses a dark circle and white text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final selected = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.selected == true &&
          widget.properties.button == true,
    );
    expect(selected, findsOneWidget);
    final circle = tester.widget<Container>(
      find.descendant(
        of: selected,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
    );
    expect((circle.decoration! as BoxDecoration).color, ActivityColors.primary);
    final number = tester.widget<Text>(
      find.descendant(
        of: selected,
        matching: find.text('${DateTime.now().day}'),
      ),
    );
    expect(number.style?.color, Colors.white);
  });

  testWidgets('month heading precedes both navigation controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final heading = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.textSpan?.toPlainText().contains('${DateTime.now().year}') ==
              true,
    );
    expect(heading, findsOneWidget);
    final text = tester.widget<Text>(heading);
    expect(text.textSpan?.style?.fontFamily, 'Georgia');
    expect(text.textSpan?.style?.color, ActivityColors.primary);
    expect(
      tester.getTopLeft(heading).dx,
      lessThan(tester.getTopLeft(find.byTooltip('Previous month')).dx),
    );
    expect(
      tester.getTopLeft(find.byTooltip('Previous month')).dx,
      lessThan(tester.getTopLeft(find.byTooltip('Next month')).dx),
    );
  });

  testWidgets('shows calendar controls and switches to week mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    expect(find.text('Month'), findsOneWidget);
    expect(find.text('Week'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.byTooltip('Next week'), findsOneWidget);
  });

  testWidgets('filters selected date entries by cadence and participant', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => CalendarData(
              [
                CalendarEntry(
                  id: '1',
                  title: 'Walk together',
                  date: today,
                  cadence: CalendarCadence.daily,
                  participantIds: const ['p'],
                ),
                CalendarEntry(
                  id: '2',
                  title: 'Weekly reading',
                  date: today,
                  cadence: CalendarCadence.weekly,
                  participantIds: const [],
                ),
              ],
              const [CalendarParticipant('p', 'Lee')],
            ),
          ),
        ],
        child: const MaterialApp(home: CalendarView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Weekly reading'), findsOneWidget);
    await tester.tap(find.text('Daily Habits'));
    await tester.pumpAndSettle();
    expect(find.text('Walk together'), findsOneWidget);
    expect(find.text('Weekly reading'), findsNothing);
  });

  testWidgets('shows Portuguese calendar controls on a compact screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('pt', 'BR'),
          supportedLocales: [Locale('en', 'US'), Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mês'), findsOneWidget);
    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calendar controls fit a compact screen with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Month'), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
