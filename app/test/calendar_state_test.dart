import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/calendar/view_models/calendar_state.dart';
import 'package:app/domain/models/calendar_data.dart';

void main() {
  test(
    'month navigation clamps leap day and preserves selection on mode change',
    () {
      final state = CalendarState(DateTime(2024, 1, 31));
      state.move(1);
      expect(state.selected, DateTime(2024, 2, 29));
      state.weekMode = true;
      expect(state.selected, DateTime(2024, 2, 29));
      expect(state.visibleDays.first, DateTime(2024, 2, 25));
      state.move(1);
      expect(state.selected, DateTime(2024, 3, 7));
    },
  );

  test('month grid contains adjacent dates and selection', () {
    final state = CalendarState(DateTime(2025, 1, 15));
    expect(state.visibleDays.first, DateTime(2024, 12, 29));
    expect(state.visibleDays, contains(DateTime(2025, 1, 15)));
    expect(state.visibleDays.length % 7, 0);
  });

  test('cadence and participant filters intersect', () {
    final state = CalendarState(DateTime(2024, 2, 29));
    state.data = CalendarData([
      CalendarEntry(
        id: '1',
        title: 'Walk',
        date: DateTime(2024, 2, 29),
        cadence: CalendarCadence.daily,
        participantIds: const ['p'],
      ),
      CalendarEntry(
        id: '2',
        title: 'Read',
        date: DateTime(2024, 2, 29),
        cadence: CalendarCadence.weekly,
        participantIds: const [],
      ),
    ], const []);
    state.cadence = CalendarCadence.daily;
    state.participantId = 'p';
    expect(state.matchingEntries.map((e) => e.title), ['Walk']);
    state.participantId = 'other';
    expect(state.matchingEntries, isEmpty);
  });

  test('month navigation crosses years and clamps non-leap February', () {
    final state = CalendarState(DateTime(2023, 12, 31));
    state.move(1);
    expect(state.selected, DateTime(2024, 1, 31));
    state.move(-1);
    expect(state.selected, DateTime(2023, 12, 31));
    state.selected = DateTime(2023, 1, 31);
    state.move(1);
    expect(state.selected, DateTime(2023, 2, 28));
  });

  test('week grid and navigation span year boundaries', () {
    final state = CalendarState(DateTime(2024, 12, 31));
    state.weekMode = true;
    expect(state.visibleDays.first, DateTime(2024, 12, 29));
    expect(state.visibleDays.last, DateTime(2025, 1, 4));
    state.move(1);
    expect(state.selected, DateTime(2025, 1, 7));
    state.weekMode = false;
    expect(state.visibleDays, contains(DateTime(2025, 1, 7)));
  });

  test('clearing a cadence keeps the participant filter', () {
    final state = CalendarState(DateTime(2025, 1, 1));
    state.data = CalendarData([
      CalendarEntry(
        id: 'a',
        title: 'Daily together',
        date: DateTime(2025, 1, 1),
        cadence: CalendarCadence.daily,
        participantIds: const ['p'],
      ),
      CalendarEntry(
        id: 'b',
        title: 'Weekly together',
        date: DateTime(2025, 1, 1),
        cadence: CalendarCadence.weekly,
        participantIds: const ['p'],
      ),
      CalendarEntry(
        id: 'c',
        title: 'Solo',
        date: DateTime(2025, 1, 1),
        cadence: CalendarCadence.daily,
        participantIds: const [],
      ),
    ], const []);
    state.participantId = 'p';
    state.cadence = CalendarCadence.daily;
    expect(state.matchingEntries.map((entry) => entry.id), ['a']);
    state.cadence = null;
    expect(state.matchingEntries.map((entry) => entry.id), ['a', 'b']);
    state.participantId = null;
    expect(state.matchingEntries.length, 3);
  });
}
