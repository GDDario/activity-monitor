import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';

import '../helpers/fake_task_repository.dart';

void main() {
  late FakeTaskRepository repo;
  late SaveTask save;
  late EnsureTaskOccurrences ensure;
  var next = 0;
  String newId() => 'h-${next++}';
  final today = LocalDate(2026, 1, 30);
  setUp(() {
    repo = FakeTaskRepository();
    save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
    ensure = EnsureTaskOccurrences(repo, newId: newId);
  });
  tearDown(() => repo.dispose());
  test(
    'first visit to old unmaterialized dates uses archived rule after edit',
    () async {
      final draft = TaskDraft.newTask(date: LocalDate(2026, 1, 1), newId: newId)
          .copyWith(
            title: 'Weekly',
            cadence: TaskCadence.weekly,
            weeklyDays: WeeklyDays(1),
            timeWindow: TimeWindow(600, 630),
          );
      final created = (await save.execute(draft)).value!.aggregate;
      final edited = TaskDraft.fromAggregate(
        created,
      ).copyWith(weeklyDays: WeeklyDays(8), timeWindow: TimeWindow(700, 730));
      final saved = (await save.execute(edited)).value!.aggregate;
      expect(saved.history.length, 1);
      expect(saved.history.single.until, LocalDate(2026, 1, 31));
      final past = (await ensure.execute(
        LocalDateRange(LocalDate(2026, 1, 12), LocalDate(2026, 1, 18)),
      )).value!;
      expect(past.map((a) => a.occurrence.scheduledDate), [
        LocalDate(2026, 1, 12),
      ]);
      expect(past.single.occurrence.timeWindow, TimeWindow(600, 630));
      final future = (await ensure.execute(
        LocalDateRange(LocalDate(2026, 2, 2), LocalDate(2026, 2, 8)),
      )).value!;
      expect(future.map((a) => a.occurrence.scheduledDate), [
        LocalDate(2026, 2, 5),
      ]);
      expect(future.single.occurrence.timeWindow, TimeWindow(700, 730));
      final second = (await save.execute(
        TaskDraft.fromAggregate(saved).copyWith(weeklyDays: WeeklyDays(16)),
      )).value!.aggregate;
      expect(second.history.length, 1);
      expect(second.history.single.until, LocalDate(2026, 1, 31));
    },
  );
  test('reconciliation retains matching IDs and all protected slots', () async {
    final created = (await save.execute(
      TaskDraft.newTask(date: today, newId: newId).copyWith(
        title: 'Daily',
        cadence: TaskCadence.daily,
        timeWindow: TimeWindow(600, 630),
      ),
    )).value!.aggregate;
    await ensure.execute(LocalDateRange(today, LocalDate(2026, 2, 5)));
    TaskOccurrence at(LocalDate date) =>
        repo.occurrences.values.singleWhere((o) => o.scheduledDate == date);
    final matching = at(LocalDate(2026, 2, 2));
    final done = at(LocalDate(2026, 2, 3));
    repo.occurrences[done.id] = done.copyWith(completed: true);
    final moved = at(LocalDate(2026, 2, 4));
    repo.occurrences[moved.id] = moved.copyWith(
      effectiveDate: LocalDate(2026, 2, 10),
      isScheduleException: true,
    );
    final removed = at(LocalDate(2026, 1, 31));
    final edited = TaskDraft.fromAggregate(created).copyWith(
      cadence: TaskCadence.weekly,
      recurrenceEnabled: true,
      weeklyDays: WeeklyDays(1),
      timeWindow: TimeWindow(700, 730),
    );
    final result = await save.execute(edited);
    expect(result.isSuccess, true);
    expect(repo.occurrences.containsKey(removed.id), false);
    expect(repo.occurrences[matching.id]!.timeWindow, TimeWindow(700, 730));
    expect(repo.occurrences[matching.id]!.id, matching.id);
    expect(repo.occurrences[done.id]!.completed, true);
    expect(repo.occurrences[moved.id]!.effectiveDate, LocalDate(2026, 2, 10));
    expect(
      repo.occurrences[created.occurrence.id]!.timeWindow,
      TimeWindow(600, 630),
    );
  });
  test('selected future occurrence and checklist exception survive a stopped repeat', () async {
    final created = (await save.execute(
      TaskDraft.newTask(
        date: today,
        newId: newId,
      ).copyWith(title: 'Daily', cadence: TaskCadence.daily),
    )).value!.aggregate;
    final cards = (await ensure.execute(
      LocalDateRange(today, LocalDate(2026, 2, 2)),
    )).value!;
    final selected = cards.singleWhere(
      (a) => a.occurrence.scheduledDate == LocalDate(2026, 2, 2),
    );
    final stopped = await save.execute(
      TaskDraft.fromAggregate(selected)
          .copyWith(cadence: TaskCadence.oneTime, recurrenceEnabled: false),
    );
    expect(stopped.isSuccess, true);
    expect(repo.occurrences.containsKey(selected.occurrence.id), true);
    expect(repo.occurrences[selected.occurrence.id]!.isScheduleException, true);
    expect(repo.occurrences.containsKey(created.occurrence.id), true);
    final future = (await ensure.execute(
      LocalDateRange(LocalDate(2026, 2, 3), LocalDate(2026, 2, 5)),
    )).value!;
    expect(future, isEmpty);
  });
  test(
    'future-only starts do not fabricate history before the first start',
    () async {
      final created = (await save.execute(
        TaskDraft.newTask(date: LocalDate(2026, 2, 15), newId: newId).copyWith(
          title: 'Future',
          cadence: TaskCadence.daily,
          timeWindow: TimeWindow(600, 630),
        ),
      )).value!.aggregate;
      final changed = (await save.execute(
        TaskDraft.fromAggregate(created)
            .copyWith(timeWindow: TimeWindow(700, 730)),
      )).value!.aggregate;
      expect(changed.history, isEmpty);
      expect(changed.task.schedule.effectiveFrom, LocalDate(2026, 1, 31));
      expect(
        (await ensure.execute(
          LocalDateRange(LocalDate(2026, 1, 31), LocalDate(2026, 2, 14)),
        )).value,
        isEmpty,
      );
      final future = (await ensure.execute(
        LocalDateRange(LocalDate(2026, 2, 16), LocalDate(2026, 2, 16)),
      )).value!.single;
      expect(future.occurrence.timeWindow, TimeWindow(700, 730));
      expect(
        repo.occurrences[created.occurrence.id]!.timeWindow,
        TimeWindow(600, 630),
      );
    },
  );
  test(
    'editing a legacy cadence leaves repeats off until explicit opt-in',
    () async {
      final created = (await save.execute(
        TaskDraft.newTask(
          date: LocalDate(2026, 1, 1),
          newId: newId,
        ).copyWith(title: 'Legacy'),
      )).value!.aggregate;
      repo.tasks[created.task.id] = Task(
        id: created.task.id,
        title: created.task.title,
        schedule: TaskSchedule(
          cadence: TaskCadence.daily,
          recurrenceEnabled: false,
          startDate: LocalDate(2026, 1, 1),
        ),
      );
      final legacy = (await repo.loadTask(
        created.task.id,
        created.occurrence.id,
      )).value!;
      final edited = (await save.execute(
        TaskDraft.fromAggregate(legacy).copyWith(notes: 'Unrelated'),
      )).value!.aggregate;
      expect(edited.task.schedule.recurrenceEnabled, false);
      expect(
        (await ensure.execute(
          LocalDateRange(LocalDate(2026, 1, 12), LocalDate(2026, 1, 18)),
        )).value,
        isEmpty,
      );
      final enabled = (await save.execute(
        TaskDraft.fromAggregate(edited).copyWith(recurrenceEnabled: true),
      )).value!.aggregate;
      expect(enabled.task.schedule.effectiveFrom, LocalDate(2026, 1, 31));
      expect(
        (await ensure.execute(
          LocalDateRange(LocalDate(2026, 1, 12), LocalDate(2026, 1, 18)),
        )).value,
        isEmpty,
      );
      expect(
        (await ensure.execute(
          LocalDateRange(LocalDate(2026, 1, 31), LocalDate(2026, 2, 2)),
        )).value!.length,
        3,
      );
    },
  );

  test('an earlier local tomorrow replaces pending rules without overlapping history', () async {
    var instant = DateTime.utc(2026, 1, 30, 12);
    final movingClockSave = SaveTask(repo, newId: newId, clock: () => instant);
    final created = (await movingClockSave.execute(
      TaskDraft.newTask(date: LocalDate(2026, 1, 1), newId: newId).copyWith(
        title: 'Travel',
        cadence: TaskCadence.weekly,
        weeklyDays: WeeklyDays(1),
      ),
    )).value!.aggregate;
    final pending = (await movingClockSave.execute(
      TaskDraft.fromAggregate(created).copyWith(weeklyDays: WeeklyDays(8)),
    )).value!.aggregate;
    instant = DateTime.utc(2026, 1, 29, 12);
    final replaced = await movingClockSave.execute(
      TaskDraft.fromAggregate(pending).copyWith(weeklyDays: WeeklyDays(16)),
    );
    expect(replaced.isSuccess, true);
    expect(
      replaced.value!.aggregate.history.single.until,
      LocalDate(2026, 1, 30),
    );
    expect(
      replaced.value!.aggregate.task.schedule.effectiveFrom,
      LocalDate(2026, 1, 30),
    );
  });
}
