import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/repositories/local_task_repository.dart';
import 'package:app/domain/models/task_result.dart';
import 'package:app/domain/models/task.dart';
import 'package:app/domain/use_cases/save_task.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

import '../helpers/task_migration_fixture.dart';

void main() {
  late Directory directory;
  late String path;
  late LocalTaskRepository repo;
  setUp(() {
    directory = Directory(
      '../.scratches/task-read-repo-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    path = '${directory.path}/tasks.sqlite';
    repo = LocalTaskRepository(TaskDatabase(path: path));
  });
  tearDown(() async {
    await repo.dispose();
    directory.deleteSync(recursive: true);
  });
  void fixture() {
    final db = sqlite3.open(path);
    createLegacyTaskFixture(db);
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
      ],
    );
    db.close();
  }

  test(
    'missing storage is unavailable and is never silently created',
    () async {
      final result = await repo.loadRange(
        LocalDateRange(LocalDate(2026, 1, 1), LocalDate(2026, 12, 31)),
      );
      expect(result.isSuccess, false);
      expect(result.failure!.code, TaskFailureCode.storageUnavailable);
      expect(File(path).existsSync(), false);
    },
  );
  test(
    'range hydration rejects corrupt semantic dates as unavailable',
    () async {
      fixture();
      final db = sqlite3.open(path);
      db.execute(
        "UPDATE task_occurrences SET effective_date='2026-02-30' WHERE id='pending-id'",
      );
      db.close();
      final result = await repo.loadRange(
        LocalDateRange(LocalDate(2026, 2, 1), LocalDate(2026, 3, 1)),
      );
      expect(result.isSuccess, false);
      expect(result.failure!.code, TaskFailureCode.storageUnavailable);
    },
  );
  test('persisted normalized tag keys must match the shared normalizer', () async {
    fixture();
    final db = sqlite3.open(path);
    db.execute(
      "INSERT INTO tags(id,name,normalized_name) VALUES ('tag','Café','wrong')",
    );
    db.execute("INSERT INTO task_tags VALUES ('pending-id','tag')");
    db.close();
    final result = await repo.loadRange(
      LocalDateRange(LocalDate(2024, 2, 29), LocalDate(2024, 2, 29)),
    );
    expect(result.isSuccess, false);
    expect(result.failure!.code, TaskFailureCode.storageUnavailable);
  });
  test('schedule snapshots load only current or historical rules relevant to the range', () async {
    fixture();
    var next = 0;
    String newId() => 'snapshot-${next++}';
    final save = SaveTask(
      repo,
      newId: newId,
      clock: () => DateTime.utc(2026, 1, 30, 12),
    );
    final active = (await save.execute(
      TaskDraft.newTask(
        date: LocalDate(2026, 1, 1),
        newId: newId,
      ).copyWith(title: 'Active', cadence: TaskCadence.daily),
    )).value!.aggregate;
    await save.execute(
      TaskDraft.newTask(
        date: LocalDate(2026, 2, 15),
        newId: newId,
      ).copyWith(title: 'Future', cadence: TaskCadence.daily),
    );
    final january = LocalDateRange(
      LocalDate(2026, 1, 1),
      LocalDate(2026, 1, 15),
    );
    expect(
      (await repo.loadScheduleSnapshot(january)).value!
          .map((s) => s.task.id)
          .toSet(),
      {active.task.id},
    );
    await save.execute(
      TaskDraft.fromAggregate(active).copyWith(cadence: TaskCadence.oneTime),
    );
    expect(
      (await repo.loadScheduleSnapshot(january)).value!
          .map((s) => s.task.id)
          .toSet(),
      {active.task.id},
    );
    final earlyFebruary = LocalDateRange(
      LocalDate(2026, 2, 1),
      LocalDate(2026, 2, 10),
    );
    expect((await repo.loadScheduleSnapshot(earlyFebruary)).value, isEmpty);
  });
}
