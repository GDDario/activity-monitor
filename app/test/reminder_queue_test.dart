import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;
import 'package:app/domain/models/task.dart';
import 'package:app/domain/value_objects/task_id.dart';
import 'package:app/domain/value_objects/occurrence_id.dart';
import 'package:app/domain/value_objects/task_title.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/reminder_preference.dart';
import 'package:app/domain/use_cases/build_reminder_queue.dart';

TaskAggregate reminderFixture(
  String id, {
  int day = 19,
  LocalDate? effective,
  int minute = 30,
  int? lead = 60,
  bool completed = false,
  bool deleted = false,
  bool timed = true,
}) {
  final date = effective ?? LocalDate(2026, 11, day),
      taskId = TaskId('task-$id');
  return TaskAggregate(
    task: Task(
      id: taskId,
      title: TaskTitle('Read $id'),
      schedule: TaskSchedule(
        cadence: TaskCadence.oneTime,
        recurrenceEnabled: false,
        startDate: date,
      ),
    ),
    occurrence: TaskOccurrence(
      id: OccurrenceId(id),
      taskId: taskId,
      scheduledDate: LocalDate(2026, 11, 18),
      effectiveDate: date,
      timeWindow: timed ? TimeWindow(minute, minute + 20) : null,
      reminder: timed
          ? ReminderPreference(lead)
          : const ReminderPreference.off(),
      completed: completed,
      deletedAtUtc: deleted ? DateTime.utc(2026, 11, 18) : null,
    ),
  );
}

void main() {
  final now = DateTime.utc(2026, 11, 18, 12);
  DateTime resolve(LocalDate d, int m) =>
      DateTime.utc(d.year, d.month, d.day, m ~/ 60, m % 60);
  test('effective date minus lead crosses midnight and preserves title', () {
    final q = const BuildReminderQueue().execute(
      [reminderFixture('a')],
      now: now,
      resolve: resolve,
    );
    expect(q.single.fireAt, DateTime.utc(2026, 11, 18, 23, 30));
    expect(q.single.title, 'Read a');
    expect(q.single.date, LocalDate(2026, 11, 19));
  });
  test('ineligible and past reminders are excluded', () {
    final items = [
      reminderFixture('off', lead: null),
      reminderFixture('untimed', timed: false),
      reminderFixture('done', completed: true),
      reminderFixture('deleted', deleted: true),
      reminderFixture('past', day: 18, minute: 600),
      reminderFixture('now', day: 18, minute: 720, lead: 0),
    ];
    expect(
      const BuildReminderQueue().execute(items, now: now, resolve: resolve),
      isEmpty,
    );
  });
  test('earliest 64 are stable, deduplicated and bounded by horizon', () {
    final items = [
      for (var i = 69; i >= 0; i--) reminderFixture('$i', minute: 100 + i),
      reminderFixture('later', day: 30),
    ];
    final q = const BuildReminderQueue().execute(
      [...items, items.first],
      now: now,
      resolve: resolve,
    );
    expect(q.length, 64);
    expect(q.first.occurrenceId, '0');
    expect(q.last.occurrenceId, '63');
    expect(
      const BuildReminderQueue().execute(
        [reminderFixture('beyond', day: 30)],
        now: now,
        horizonDays: 2,
        resolve: resolve,
      ),
      isEmpty,
    );
  });
  test('nonexistent wall time is skipped rather than silently shifted', () {
    expect(
      const BuildReminderQueue().execute(
        [reminderFixture('gap')],
        now: now,
        resolve: (d, m) => resolve(d, m + 60),
      ),
      isEmpty,
    );
  });
  test('rolling horizon includes a next-day task whose lead fires inside the window', () {
    final late = DateTime.utc(2026, 11, 18, 23, 45);
    final q = const BuildReminderQueue().execute(
      [
        reminderFixture(
          'inside',
          effective: LocalDate(2026, 12, 19),
          minute: 15,
        ),
        reminderFixture(
          'outside',
          effective: LocalDate(2026, 12, 19),
          minute: 60,
          lead: 0,
        ),
      ],
      now: late,
      resolve: resolve,
    );
    expect(q.map((r) => r.occurrenceId), ['inside']);
    expect(q.single.fireAt, DateTime.utc(2026, 12, 18, 23, 15));
  });
  test(
    'real zone DST gap is skipped and repeated wall time produces one reminder',
    () {
      zones.initializeTimeZones();
      final zone = tz.getLocation('America/New_York');
      DateTime wall(LocalDate date, int minute) => tz.TZDateTime(
        zone,
        date.year,
        date.month,
        date.day,
        minute ~/ 60,
        minute % 60,
      );
      final gap = const BuildReminderQueue().execute(
        [
          reminderFixture(
            'gap',
            effective: LocalDate(2026, 3, 8),
            minute: 150,
            lead: 0,
          ),
        ],
        now: tz.TZDateTime(zone, 2026, 3, 8),
        resolve: wall,
      );
      expect(gap, isEmpty);
      final repeated = const BuildReminderQueue().execute(
        [
          reminderFixture(
            'repeat',
            effective: LocalDate(2026, 11, 1),
            minute: 90,
            lead: 0,
          ),
        ],
        now: tz.TZDateTime(zone, 2026, 11, 1),
        resolve: wall,
      );
      expect(repeated.length, 1);
      expect(repeated.single.startAt.hour, 1);
      expect(repeated.single.startAt.minute, 30);
    },
  );
}
