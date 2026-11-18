import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/calculate_daily_streak.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/local_date.dart';

void main() {
  final id = TaskId('daily');
  final today = LocalDate(2026, 1, 30);
  final calculator = CalculateDailyStreak();
  TaskOccurrence occurrence(
    int day, {
    bool done = true,
    bool deleted = false,
    LocalDate? effective,
  }) => TaskOccurrence(
    id: OccurrenceId('o-$day'),
    taskId: id,
    scheduledDate: LocalDate(2026, 1, day),
    effectiveDate: effective ?? LocalDate(2026, 1, day),
    completed: done,
    deletedAtUtc: deleted ? DateTime.utc(2026) : null,
  );
  TaskStreakHistory history(
    List<TaskOccurrence> rows, {
    bool visible = true,
    TaskSchedule? current,
    List<SchedulePeriod> periods = const [],
  }) => TaskStreakHistory(
    snapshot: TaskScheduleSnapshot(
      task: Task(
        id: id,
        title: TaskTitle('Read'),
        schedule:
            current ??
            TaskSchedule(
              cadence: TaskCadence.daily,
              recurrenceEnabled: true,
              startDate: LocalDate(2026, 1, 1),
              streakEnabled: visible,
            ),
      ),
      history: periods,
    ),
    occurrences: rows,
  );
  test(
    'pending today preserves yesterday run and completed today extends it',
    () {
      final rows = [
        occurrence(27, done: false),
        occurrence(28),
        occurrence(29),
        occurrence(30, done: false),
      ];
      expect(calculator.execute(history(rows), today), 2);
      expect(
        calculator.execute(
          history([
            ...rows.where((o) => o.scheduledDate != today),
            occurrence(30),
          ]),
          today,
        ),
        3,
      );
    },
  );
  test('deleted gap breaks run; postponed completion counts original date', () {
    expect(
      calculator.execute(
        history([
          occurrence(28),
          occurrence(29, deleted: true),
          occurrence(30),
        ]),
        today,
      ),
      1,
    );
    expect(
      calculator.execute(
        history([
          occurrence(28),
          occurrence(29, effective: today),
          occurrence(30),
        ]),
        today,
      ),
      3,
    );
  });
  test('future rows excluded and disabled tracking is not a zero', () {
    expect(
      calculator.execute(
        history([occurrence(29), occurrence(30), occurrence(31)]),
        today,
      ),
      2,
    );
    expect(
      calculator.execute(history([occurrence(30)], visible: false), today),
      isNull,
    );
  });
  test('daily return starts a new segment and same-daily visibility/default changes do not', () {
    final daily = TaskSchedule(
      cadence: TaskCadence.daily,
      recurrenceEnabled: true,
      startDate: LocalDate(2026, 1, 1),
      effectiveFrom: LocalDate(2026, 1, 30),
      streakEnabled: true,
    );
    final weekly = TaskSchedule(
      cadence: TaskCadence.weekly,
      recurrenceEnabled: false,
      startDate: LocalDate(2026, 1, 1),
      effectiveFrom: LocalDate(2026, 1, 28),
    );
    final original = TaskSchedule(
      cadence: TaskCadence.daily,
      recurrenceEnabled: true,
      startDate: LocalDate(2026, 1, 1),
      effectiveFrom: LocalDate(2026, 1, 1),
    );
    final rows = [
      occurrence(27),
      occurrence(28),
      occurrence(29),
      occurrence(30),
    ];
    expect(
      calculator.execute(
        history(
          rows,
          current: daily,
          periods: [
            SchedulePeriod(original, until: LocalDate(2026, 1, 28)),
            SchedulePeriod(weekly, until: LocalDate(2026, 1, 30)),
          ],
        ),
        today,
      ),
      1,
    );
    expect(
      calculator.execute(
        history(
          rows,
          current: daily,
          periods: [SchedulePeriod(original, until: LocalDate(2026, 1, 30))],
        ),
        today,
      ),
      4,
    );
  });
}
