import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/calendar_data.dart';
import 'package:app/ui/calendar/view_models/calendar_view_model.dart';

void main() {
  test('an older load cannot overwrite a newer calendar snapshot', () async {
    final first = Completer<CalendarData>();
    final second = Completer<CalendarData>();
    var calls = 0;
    final model = CalendarViewModel(
      DateTime(2024),
      () => calls++ == 0 ? first.future : second.future,
    );
    addTearDown(model.dispose);
    final oldLoad = model.load();
    final latestLoad = model.load();
    final latest = CalendarData([], []);
    second.complete(latest);
    await latestLoad;
    first.complete(const CalendarData([], []));
    await oldLoad;
    expect(model.calendar.data, same(latest));
  });

  test('loads calendar data and notifies listeners', () async {
    final data = CalendarData([], []);
    final model = CalendarViewModel(DateTime(2024, 1, 31), () async => data);
    addTearDown(model.dispose);
    var notifications = 0;
    model.addListener(() => notifications++);
    await model.load();
    expect(model.calendar.data, same(data));
    expect(model.isLoading, false);
    expect(notifications, greaterThan(0));
  });

  test('date and filter commands update state and notify listeners', () {
    final model = CalendarViewModel(
      DateTime(2024, 1, 31),
      () async => const CalendarData([], []),
    );
    addTearDown(model.dispose);
    var notifications = 0;
    model.addListener(() => notifications++);
    model.move(1);
    expect(model.calendar.selected, DateTime(2024, 2, 29));
    model.setWeekMode(true);
    model.selectDate(DateTime(2024, 3, 4, 12));
    expect(model.calendar.selected, DateTime(2024, 3, 4));
    model.setCadence(CalendarCadence.weekly);
    model.toggleParticipant('p');
    expect(model.calendar.participantId, 'p');
    model.toggleParticipant('p');
    expect(model.calendar.participantId, isNull);
    expect(notifications, 6);
  });

  test('exposes data loading failures as unavailable', () async {
    final model = CalendarViewModel(
      DateTime(2024),
      () async => throw StateError('private'),
    );
    addTearDown(model.dispose);
    await model.load();
    expect(model.hasError, true);
    expect(model.isLoading, false);
  });

  test('ignores a completed load after disposal', () async {
    final result = Completer<CalendarData>();
    final model = CalendarViewModel(DateTime(2024), () => result.future);
    final pending = model.load();
    model.dispose();
    result.complete(const CalendarData([], []));
    await pending;
  });
}
