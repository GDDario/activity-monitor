import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/domain/models/task_schedule.dart';

void main() {
  test('time windows require paired increasing minutes within a day', () {
    expect(() => TimeWindow(600, 600), throwsArgumentError);
    expect(() => TimeWindow(600, 599), throwsArgumentError);
    expect(() => TimeWindow(-1, 20), throwsArgumentError);
    expect(() => TimeWindow(0, 1440), throwsArgumentError);
    expect(TimeWindow(60, 90).durationMinutes, 30);
  });
  test('dates validate and step through leap and year boundaries', () {
    expect(() => LocalDate(2023, 2, 29), throwsArgumentError);
    expect(LocalDate(2024, 2, 28).addDays(1), LocalDate(2024, 2, 29));
    expect(LocalDate(2024, 12, 31).addDays(1), LocalDate(2025, 1, 1));
    expect(
      () => LocalDateRange(LocalDate(2024, 2, 2), LocalDate(2024, 2, 1)),
      throwsArgumentError,
    );
  });
  test('schedule enforces cadence and reminder invariants', () {
    final date = LocalDate(2024, 1, 1);
    expect(() => WeeklyDays(128), throwsArgumentError);
    expect(WeeklyDays(1).contains(DateTime.monday), isTrue);
    expect(() => ReminderPreference(10), throwsArgumentError);
    expect(
      () => TaskSchedule(
        cadence: TaskCadence.weekly,
        recurrenceEnabled: true,
        startDate: date,
        weeklyDays: WeeklyDays(0),
      ),
      throwsArgumentError,
    );
    expect(
      () => TaskSchedule(
        cadence: TaskCadence.oneTime,
        recurrenceEnabled: false,
        startDate: date,
        reminder: ReminderPreference(5),
      ),
      throwsArgumentError,
    );
    final legacy = TaskSchedule(
      cadence: TaskCadence.weekly,
      recurrenceEnabled: false,
      startDate: date,
    );
    expect(legacy.recurrenceEnabled, isFalse);
  });
}
