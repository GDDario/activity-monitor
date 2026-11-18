import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/use_cases/ensure_task_occurrences.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/time_window.dart';
import 'package:app/domain/value_objects/weekly_days.dart';

import '../helpers/task_migration_fixture.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalTaskRepository repo;
  var next = 0;
  String newId() => 'm-${next++}';
  setUp(() {
    directory = Directory(
      '../.scratches/task-material-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    path = '${directory.path}/tasks.sqlite';
    final db = sqlite3.open(path);
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
      ],
    );
    db.execute('DELETE FROM tasks');
    db.close();
    repo = LocalTaskRepository(TaskDatabase(path: path));
  });
  tearDown(() async {
    await repo.dispose();
    directory.deleteSync(recursive: true);
  });
  test(
    'two connections generate one slot each and revisiting emits no event',
    () async {
      final today = LocalDate(2026, 1, 30);
      final range = LocalDateRange(today, LocalDate(2026, 2, 2));
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final a = (await save.execute(
        TaskDraft.newTask(
          date: today,
          newId: newId,
        ).copyWith(title: 'Daily', cadence: TaskCadence.daily),
      )).value!.aggregate;
      final second = LocalTaskRepository(TaskDatabase(path: path));
      addTearDown(second.dispose);
      final results = await Future.wait([
        EnsureTaskOccurrences(repo, newId: newId).execute(range),
        EnsureTaskOccurrences(second, newId: newId).execute(range),
      ]);
      expect(results.every((r) => r.isSuccess), true);
      expect(results.map((r) => r.value!.length), [4, 4]);
      final db = sqlite3.open(path);
      expect(
        db.select('SELECT * FROM task_occurrences WHERE task_id=?', [
          a.task.id.value,
        ]).length,
        4,
      );
      db.close();
      final changes = <TaskChange>[];
      final subscription = repo.changes.listen(changes.add);
      await EnsureTaskOccurrences(repo, newId: newId).execute(range);
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);
      await subscription.cancel();
    },
  );
  test(
    'history and protected slots survive reopen and a later first visit',
    () async {
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final ensure = EnsureTaskOccurrences(repo, newId: newId);
      final a = (await save.execute(
        TaskDraft.newTask(date: LocalDate(2026, 1, 1), newId: newId).copyWith(
          title: 'Weekly',
          cadence: TaskCadence.weekly,
          weeklyDays: WeeklyDays(1),
          timeWindow: TimeWindow(600, 630),
        ),
      )).value!.aggregate;
      await ensure.execute(
        LocalDateRange(LocalDate(2026, 2, 1), LocalDate(2026, 2, 14)),
      );
      final pending = (await repo.loadRange(
        LocalDateRange(LocalDate(2026, 2, 9), LocalDate(2026, 2, 9)),
      )).value!.single;
      final deleted = pending.occurrence.copyWith(
        deletedAtUtc: DateTime.utc(2026, 1, 30, 12),
        revision: pending.occurrence.revision + 1,
        isScheduleException: true,
      );
      expect(
        (await repo.applyOccurrenceChange(
          PreparedOccurrenceChange(
            before: pending.occurrence,
            after: deleted,
            expected: pending.expected,
            undoable: true,
          ),
        )).isSuccess,
        true,
      );
      expect(
        (await save.execute(
          TaskDraft.fromAggregate(a).copyWith(
            weeklyDays: WeeklyDays(8),
            timeWindow: TimeWindow(700, 730),
          ),
        )).isSuccess,
        true,
      );
      await repo.dispose();
      repo = LocalTaskRepository(TaskDatabase(path: path));
      final past = (await EnsureTaskOccurrences(repo, newId: newId).execute(
        LocalDateRange(LocalDate(2026, 1, 12), LocalDate(2026, 1, 18)),
      )).value!;
      expect(past.single.occurrence.scheduledDate, LocalDate(2026, 1, 12));
      expect(past.single.occurrence.timeWindow, TimeWindow(600, 630));
      final future = (await EnsureTaskOccurrences(repo, newId: newId).execute(
        LocalDateRange(LocalDate(2026, 2, 2), LocalDate(2026, 2, 14)),
      )).value!;
      expect(future.map((a) => a.occurrence.scheduledDate).toSet(), {
        LocalDate(2026, 2, 5),
        LocalDate(2026, 2, 12),
      });
      final db = sqlite3.open(path);
      expect(
        db.select('SELECT deleted_at_utc FROM task_occurrences WHERE id=?', [
          deleted.id.value,
        ]).single['deleted_at_utc'],
        isNotNull,
      );
      expect(
        db.select('SELECT * FROM task_schedule_history WHERE task_id=?', [
          a.task.id.value,
        ]).length,
        1,
      );
      db.close();
    },
  );
  test('unrelated occurrence ID collision rolls back instead of hiding constraints', () async {
    final date = LocalDate(2026, 1, 30);
    final save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
    final a = (await save.execute(
      TaskDraft.newTask(
        date: date,
        newId: newId,
      ).copyWith(title: 'Daily', cadence: TaskCadence.daily),
    )).value!.aggregate;
    final result = await repo.ensureOccurrences(
      [
        TaskOccurrence(
          id: a.occurrence.id,
          taskId: a.task.id,
          scheduledDate: LocalDate(2026, 1, 31),
          effectiveDate: LocalDate(2026, 1, 31),
        ),
      ],
      {a.task.id: a.task.revision},
    );
    expect(result.failure!.code, TaskFailureCode.storageUnavailable);
    final db = sqlite3.open(path);
    expect(db.select('SELECT * FROM task_occurrences').length, 1);
    db.close();
  });
  test(
    'stale expansion cannot commit after a shared scheduling revision',
    () async {
      final date = LocalDate(2026, 1, 30);
      final save = SaveTask(
        repo,
        newId: newId,
        clock: () => DateTime.utc(2026, 1, 30, 12),
      );
      final a = (await save.execute(
        TaskDraft.newTask(
          date: date,
          newId: newId,
        ).copyWith(title: 'Daily', cadence: TaskCadence.daily),
      )).value!.aggregate;
      final candidate = a.occurrence.copyWith(
        effectiveDate: LocalDate(2026, 1, 31),
      );
      await save.execute(TaskDraft.fromAggregate(a).copyWith(title: 'Renamed'));
      final result = await repo.ensureOccurrences(
        [candidate],
        {a.task.id: a.task.revision},
      );
      expect(result.failure!.code, TaskFailureCode.staleRevision);
      final db = sqlite3.open(path);
      expect(db.select('SELECT * FROM task_occurrences').length, 1);
      db.close();
    },
  );
}
