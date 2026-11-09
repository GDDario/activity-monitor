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
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';
import 'package:app/domain/value_objects/weekly_days.dart';

import '../helpers/task_migration_fixture.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalTaskRepository repo;
  late SaveTask save;
  var next = 0;
  String newId() => 'a-${next++}';
  final visible = LocalDateRange(LocalDate(2026, 2, 1), LocalDate(2026, 2, 7));
  setUp(() {
    directory = Directory(
      '../.scratches/task-atomic-schedule-${DateTime.now().microsecondsSinceEpoch}',
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
    save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
  });
  tearDown(() async {
    await repo.dispose();
    directory.deleteSync(recursive: true);
  });
  TaskDraft weekly() =>
      TaskDraft.newTask(date: LocalDate(2026, 1, 1), newId: newId).copyWith(
        title: 'Weekly',
        cadence: TaskCadence.weekly,
        weeklyDays: WeeklyDays(1),
      );
  test(
    'creation and edited visible slots commit with the rule before any refresh',
    () async {
      final created = (await save.execute(
        weekly(),
        requestedRange: visible,
      )).value!.aggregate;
      expect(
        (await repo.loadRange(visible)).value!
            .map((a) => a.occurrence.scheduledDate),
        [LocalDate(2026, 2, 2)],
      );
      final changed = await save.execute(
        TaskDraft.fromAggregate(created).copyWith(weeklyDays: WeeklyDays(8)),
        requestedRange: visible,
      );
      expect(changed.isSuccess, true);
      expect(
        (await repo.loadRange(visible)).value!
            .map((a) => a.occurrence.scheduledDate),
        [LocalDate(2026, 2, 5)],
      );
      expect(
        changed.value!.receipt.affectedDates,
        containsAll([LocalDate(2026, 2, 2), LocalDate(2026, 2, 5)]),
      );
    },
  );
  test('failure generating a newly matching slot rolls back rule history and reconciliation', () async {
    final created = (await save.execute(
      weekly(),
      requestedRange: visible,
    )).value!.aggregate;
    final db = sqlite3.open(path);
    db.execute(
      "CREATE TRIGGER fail_new_slot BEFORE INSERT ON task_occurrences WHEN NEW.scheduled_date='2026-02-05' BEGIN SELECT RAISE(ABORT, 'private'); END",
    );
    db.close();
    final changes = <TaskChange>[];
    final subscription = repo.changes.listen(changes.add);
    final failed = await save.execute(
      TaskDraft.fromAggregate(created).copyWith(weeklyDays: WeeklyDays(8)),
      requestedRange: visible,
    );
    expect(failed.failure!.code, TaskFailureCode.storageUnavailable);
    final unchanged = (await repo.loadTask(
      created.task.id,
      created.occurrence.id,
    )).value!;
    expect(unchanged.task.schedule.weeklyDays, WeeklyDays(1));
    expect(unchanged.history, isEmpty);
    expect(
      (await repo.loadRange(visible)).value!
          .map((a) => a.occurrence.scheduledDate),
      [LocalDate(2026, 2, 2)],
    );
    await Future<void>.delayed(Duration.zero);
    expect(changes, isEmpty);
    await subscription.cancel();
  });
}
