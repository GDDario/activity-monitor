import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app/ui/calendar/views/calendar_view.dart';
import 'package:app/app/dependencies/app_dependencies.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/core/theme/activity_theme.dart';
import 'package:app/ui/core/theme/activity_colors.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';

void main() {
  testWidgets(
    'counts pending and done entries for the selected date and filters',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final day = DateTime(2024, 1, 15);
      final model = CalendarViewModel(
        day,
        () async => CalendarData(
          [
            CalendarEntry(
              id: 'p',
              title: 'Pending',
              date: day,
              cadence: CalendarCadence.daily,
              participantIds: const ['person'],
            ),
            CalendarEntry(
              id: 'd',
              title: 'Done',
              date: day,
              cadence: CalendarCadence.daily,
              participantIds: const ['person'],
              isDone: true,
            ),
            CalendarEntry(
              id: 'other',
              title: 'Other',
              date: day,
              cadence: CalendarCadence.weekly,
              participantIds: const [],
            ),
            CalendarEntry(
              id: 'tomorrow',
              title: 'Tomorrow',
              date: DateTime(2024, 1, 16),
              cadence: CalendarCadence.daily,
              participantIds: const [],
              isDone: true,
            ),
          ],
          const [CalendarParticipant('person', 'Lee')],
        ),
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
      expect(find.text('2 pending · 1 done'), findsOneWidget);
      await tester.tap(find.text('Daily Habits'));
      await tester.pumpAndSettle();
      expect(find.text('1 pending · 1 done'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Lee'));
      await tester.pumpAndSettle();
      expect(find.text('1 pending · 1 done'), findsOneWidget);
      model.selectDate(DateTime(2024, 1, 16));
      await tester.pumpAndSettle();
      expect(find.text('0 pending · 0 done'), findsOneWidget);
    },
  );

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
      tester
          .getBottomLeft(find.byKey(const ValueKey('calendar-mode-toggle')))
          .dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(Card).first).dy),
    );
  });

  testWidgets('places Create task alongside the view selector', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    final create = tester.getCenter(
      find.widgetWithText(OutlinedButton, 'Create task'),
    );
    final toggle = tester.getCenter(
      find.byKey(const ValueKey('calendar-mode-toggle')),
    );
    expect(create.dy, toggle.dy);
    expect(create.dx, lessThan(toggle.dx));
  });

  testWidgets('header creation button includes an add icon', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    expect(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'Create task'),
        matching: find.byIcon(Icons.add),
      ),
      findsOneWidget,
    );
  });

  testWidgets('collaborative legend uses the secondary color', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalendarView())),
    );
    final legend = find
        .ancestor(of: find.text('Collaborative'), matching: find.byType(Row))
        .first;
    final bullet = tester.widget<Icon>(
      find.descendant(of: legend, matching: find.byIcon(Icons.circle)),
    );
    expect(bullet.color, ActivityColors.secondary);
    expect(bullet.size, greaterThanOrEqualTo(8));
  });

  testWidgets('calendar legend uses compact readable labels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(325, 1600));
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
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final solo = tester.widget<Text>(find.text('Solo / Habit'));
    expect(solo.style?.fontSize, 11);
    expect(solo.style?.color, ActivityColors.mutedInk);
  });

  testWidgets('date indicators distinguish solo and collaborative entries', (
    tester,
  ) async {
    final today = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => CalendarData([
              CalendarEntry(
                id: 'solo',
                title: 'Solo',
                date: today,
                cadence: CalendarCadence.oneTime,
                participantIds: const [],
              ),
              CalendarEntry(
                id: 'shared',
                title: 'Shared',
                date: today,
                cadence: CalendarCadence.daily,
                participantIds: const ['person'],
              ),
            ], const []),
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
    final solo = tester.widget<Icon>(
      find.descendant(
        of: selected,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == Icons.circle &&
              widget.color == ActivityColors.primaryContainer,
        ),
      ),
    );
    final collaborative = tester.widget<Icon>(
      find.descendant(
        of: selected,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.icon == Icons.circle &&
              widget.color == ActivityColors.secondary,
        ),
      ),
    );
    final cadence = tester.widget<Icon>(
      find.descendant(of: selected, matching: find.byIcon(Icons.sync)),
    );
    expect(solo.size, greaterThanOrEqualTo(8));
    expect(collaborative.size, greaterThanOrEqualTo(8));
    expect(collaborative.size, solo.size);
    expect(cadence.size, greaterThanOrEqualTo(10));
    expect(solo.color, ActivityColors.primaryContainer);
    expect(collaborative.color, ActivityColors.secondary);
    final semantics = tester.widget<Semantics>(selected);
    expect(semantics.properties.label, contains('Solo / Habit'));
    expect(semantics.properties.label, contains('Collaborative'));
    expect(semantics.properties.label, contains('Cadence active'));
  });

  testWidgets('selected date indicators are larger and spaced from the date', (
    tester,
  ) async {
    final today = DateTime.now();
    final otherDay = DateTime(today.year, today.month, today.day == 1 ? 2 : 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => CalendarData([
              CalendarEntry(
                id: 'a',
                title: 'Selected',
                date: today,
                cadence: CalendarCadence.daily,
                participantIds: const [],
              ),
              CalendarEntry(
                id: 'b',
                title: 'Other',
                date: otherDay,
                cadence: CalendarCadence.daily,
                participantIds: const [],
              ),
            ], const []),
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
    final other = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.selected == false &&
          (widget.properties.label?.contains('Solo / Habit') ?? false),
    );
    final selectedIcon = find.descendant(
      of: selected,
      matching: find.byIcon(Icons.circle),
    );
    final otherIcon = find.descendant(
      of: other,
      matching: find.byIcon(Icons.circle),
    );
    expect(
      tester.widget<Icon>(selectedIcon).size!,
      greaterThan(tester.widget<Icon>(otherIcon).size!),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(of: selected, matching: find.byIcon(Icons.sync)),
          )
          .size!,
      greaterThan(
        tester
            .widget<Icon>(
              find.descendant(of: other, matching: find.byIcon(Icons.sync)),
            )
            .size!,
      ),
    );
    final dateCircle = find.descendant(
      of: selected,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
    );
    expect(
      tester.getTopLeft(selectedIcon).dy - tester.getBottomLeft(dateCircle).dy,
      greaterThanOrEqualTo(2),
    );
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
      find.text('All Tasks'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final selected = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'All Tasks'),
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
    final toggle = find.byType(SegmentedButton<bool>);
    expect(toggle, findsOneWidget);
    SegmentedButton<bool> control() =>
        tester.widget<SegmentedButton<bool>>(toggle);
    final rail = find.byKey(const ValueKey('calendar-mode-rail'));
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(rail).height,
      lessThan(tester.getSize(toggle).height),
    );
    expect(
      tester.getSize(rail).height - tester.getSize(find.text('Month')).height,
      closeTo(12, 0.01),
    );
    expect(control().selected, {false});
    expect(control().showSelectedIcon, false);
    for (final state in [
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    ]) {
      expect(
        control().style?.overlayColor?.resolve({state}),
        Colors.transparent,
      );
    }
    expect(control().style?.splashFactory, NoSplash.splashFactory);
    expect(
      control().style?.textStyle?.resolve({WidgetState.focused})?.decoration,
      TextDecoration.underline,
    );
    final indicator = find.byKey(const ValueKey('calendar-mode-indicator'));
    final start = tester.getTopLeft(indicator).dx;
    await tester.tap(find.text('Week'));
    await tester.pump();
    expect(find.byTooltip('Next week'), findsOneWidget);
    expect(control().selected, {true});
    await tester.pump(const Duration(milliseconds: 80));
    final halfway = tester.getTopLeft(indicator).dx;
    expect(halfway, greaterThan(start));
    await tester.pumpAndSettle();
    final end = tester.getTopLeft(indicator).dx;
    expect(end, greaterThan(halfway));
    await tester.tap(find.text('Month'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(indicator).dx, lessThan(end));
    expect(tester.getTopLeft(indicator).dx, greaterThan(start));
    await tester.pumpAndSettle();
    expect(control().selected, {false});
    expect(tester.getTopLeft(indicator).dx, closeTo(start, 0.01));
  });

  testWidgets('calendar mode respects reduced motion', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: const CalendarView(),
        ),
      ),
    );
    final indicator = find.byKey(const ValueKey('calendar-mode-indicator'));
    final start = tester.getTopLeft(indicator).dx;
    await tester.tap(find.text('Week'));
    await tester.pump();
    final end = tester.getTopLeft(indicator).dx;
    expect(end, greaterThan(start));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(indicator).dx, end);
  });

  testWidgets('navigates leap month and week while preserving selection', (
    tester,
  ) async {
    final model = CalendarViewModel(
      DateTime(2024, 1, 31),
      () async => const CalendarData([], []),
    );
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarViewModelProvider.overrideWith((ref) => model)],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    Finder selectedDate() => find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          widget.properties.selected == true &&
          (widget.properties.label?.contains('2024') ?? false),
    );
    expect(
      tester.widget<Semantics>(selectedDate()).properties.label,
      contains('January 31, 2024'),
    );
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(selectedDate()).properties.label,
      contains('February 29, 2024'),
    );
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(selectedDate()).properties.label,
      contains('February 29, 2024'),
    );
    await tester.tap(find.byTooltip('Next week'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Semantics>(selectedDate()).properties.label,
      contains('March 7, 2024'),
    );
    expect(find.widgetWithText(OutlinedButton, 'Today'), findsNothing);
    expect(model.calendar.selected, DateTime(2024, 3, 7));
  });

  testWidgets('shows a helpful empty state for a day without entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => const CalendarData([], []),
          ),
        ],
        child: const MaterialApp(home: CalendarView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No entries for this day and these filters.'),
      findsOneWidget,
    );
  });

  testWidgets('keyboard can focus and activate an overflowing filter', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
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
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final weekly = find.widgetWithText(FilterChip, 'Weekly');
    var focused = false;
    for (var i = 0; i < 100 && !focused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context != null && weekly.evaluate().isNotEmpty) {
        focused = find
            .ancestor(of: find.byWidget(context.widget), matching: weekly)
            .evaluate()
            .isNotEmpty;
      }
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(weekly).selected, isTrue);
  });

  testWidgets('keyboard can focus and select a calendar date', (tester) async {
    final model = CalendarViewModel(
      DateTime(2024, 1, 15),
      () async => const CalendarData([], []),
    );
    addTearDown(model.dispose);
    await model.load();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [calendarViewModelProvider.overrideWith((ref) => model)],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.button == true &&
          (widget.properties.label?.contains('January 16, 2024') ?? false),
    );
    var focused = false;
    for (var i = 0; i < 100 && !focused; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final context = FocusManager.instance.primaryFocus?.context;
      if (context != null) {
        focused = find
            .ancestor(of: find.byWidget(context.widget), matching: target)
            .evaluate()
            .isNotEmpty;
      }
    }
    expect(focused, isTrue);
    final buttonFinder = find.descendant(
      of: target,
      matching: find.byType(TextButton),
    );
    final button = tester.widget<TextButton>(buttonFinder);
    final focusedOverlay =
        button.style?.overlayColor?.resolve({WidgetState.focused}) ??
        button
            .defaultStyleOf(tester.element(buttonFinder))
            .overlayColor
            ?.resolve({WidgetState.focused});
    expect(focusedOverlay?.a ?? 0, greaterThan(0));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(tester.widget<Semantics>(target).properties.selected, true);
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

  testWidgets(
    'participant and recurrence filters combine and reset independently',
    (tester) async {
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
                    id: 'daily',
                    title: 'Daily with Lee',
                    date: today,
                    cadence: CalendarCadence.daily,
                    participantIds: const ['p'],
                  ),
                  CalendarEntry(
                    id: 'weekly',
                    title: 'Weekly with Lee',
                    date: today,
                    cadence: CalendarCadence.weekly,
                    participantIds: const ['p'],
                  ),
                  CalendarEntry(
                    id: 'solo',
                    title: 'Daily alone',
                    date: today,
                    cadence: CalendarCadence.daily,
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
      await tester.tap(find.text('Daily Habits'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Lee'));
      await tester.tap(find.widgetWithText(FilterChip, 'Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Daily with Lee'), findsOneWidget);
      expect(find.text('Weekly with Lee'), findsNothing);
      expect(find.text('Daily alone'), findsNothing);
      await tester.ensureVisible(find.text('All Tasks'));
      await tester.tap(find.text('All Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Weekly with Lee'), findsOneWidget);
      expect(find.text('Daily alone'), findsNothing);
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'Lee'));
      await tester.tap(find.widgetWithText(FilterChip, 'Lee'));
      await tester.pumpAndSettle();
      expect(find.text('Daily alone'), findsOneWidget);
    },
  );

  testWidgets('selected-date cards show stored recurrence and participant', (
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
                  id: 'a',
                  title: 'Weekly walk',
                  date: today,
                  cadence: CalendarCadence.weekly,
                  participantIds: const ['p'],
                ),
              ],
              const [CalendarParticipant('p', 'Lee')],
            ),
          ),
        ],
        child: MaterialApp(
          theme: ActivityTheme.light(),
          home: const CalendarView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final card = find.ancestor(
      of: find.text('Weekly walk'),
      matching: find.byType(Card),
    );
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Weekly')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('Lee')),
      findsOneWidget,
    );
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
    expect(find.widgetWithText(OutlinedButton, 'Criar tarefa'), findsOneWidget);
    expect(find.byTooltip('Abrir calendário'), findsOneWidget);
    expect(find.byTooltip('Abrir notificações'), findsOneWidget);
    expect(find.text('Pessoas'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Todas as tarefas'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Todas as tarefas'), findsOneWidget);
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

  testWidgets('date indicators fit compact screens with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarDataProvider.overrideWith(
            (ref) async => CalendarData([
              CalendarEntry(
                id: 'solo',
                title: 'Solo',
                date: today,
                cadence: CalendarCadence.daily,
                participantIds: const [],
              ),
              CalendarEntry(
                id: 'shared',
                title: 'Shared',
                date: today,
                cadence: CalendarCadence.weekly,
                participantIds: const ['p'],
              ),
            ], const []),
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
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide calendar remains usable with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
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
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byTooltip('Next month'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Portuguese calendar announces the selected date and empty state',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = CalendarViewModel(
        DateTime(2024, 1, 31),
        () async => const CalendarData([], []),
      );
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarViewModelProvider.overrideWith((ref) => model)],
          child: const MaterialApp(
            locale: Locale('pt', 'BR'),
            supportedLocales: [Locale('en', 'US'), Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: CalendarView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selected = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.button == true &&
            widget.properties.selected == true &&
            (widget.properties.label?.contains('2024') ?? false),
      );
      expect(
        tester.widget<Semantics>(selected).properties.label,
        contains('janeiro'),
      );
      expect(
        find.text('Nenhuma atividade para este dia e filtros.'),
        findsOneWidget,
      );
      expect(find.text('0 pendentes · 0 concluídas'), findsOneWidget);
    },
  );

  for (final size in [const Size(360, 800), const Size(1200, 900)]) {
    testWidgets('Portuguese navigation and failure state at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = CalendarViewModel(
        DateTime(2024, 1, 31),
        () async => throw StateError('private detail'),
      );
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarViewModelProvider.overrideWith((ref) => model)],
          child: MaterialApp(
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('en', 'US'), Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      await tester.ensureVisible(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Próximo mês'));
      await tester.pumpAndSettle();
      expect(model.calendar.selected, DateTime(2024, 2, 29));
      await tester.scrollUntilVisible(
        find.text('Os dados do calendário estão indisponíveis no momento.'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(
        find.text('Os dados do calendário estão indisponíveis no momento.'),
        findsOneWidget,
      );
      expect(find.textContaining('private detail'), findsNothing);
      expect(find.textContaining('pendentes ·'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
