import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/task_database.dart';
import 'package:app/data/services/task_row_mapper.dart';

import '../helpers/task_migration_fixture.dart';

void main() {
  test('isolated range load includes moved-in and excludes tombstones after reopen', () async {
    final directory = Directory(
      '../.scratches/task-read-test-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync(recursive: true);
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}/tasks.sqlite';
    final db = sqlite3.open(path);
    migrateDatabase(
      db,
      migrations: [
        ...historicalTaskMigrations(),
        const Migration0004CreateTaskTables(),
      ],
    );
    db.execute('DELETE FROM tasks');
    db.execute(
      "INSERT INTO tasks(id,title,priority,cadence,recurrence_enabled,start_date,streak_enabled,revision) VALUES ('task','  Preserved  ','low','daily',0,'2024-02-29',0,0)",
    );
    db.execute(
      "INSERT INTO task_occurrences(id,task_id,scheduled_date,effective_date,completed,is_schedule_exception,revision) VALUES ('moved','task','2024-02-29','2026-01-30',1,1,0)",
    );
    db.execute(
      "INSERT INTO task_occurrences(id,task_id,scheduled_date,effective_date,completed,deleted_at_utc,is_schedule_exception,revision) VALUES ('deleted','task','2024-03-01','2026-01-30',0,'2026-01-30T12:00:00Z',1,0)",
    );
    db.close();
    final rows = await TaskDatabase(path: path)
        .loadVisible(from: '2026-01-30', through: '2026-01-30');
    expect(rows.length, 1);
    final a = taskAggregateFromRow(rows.single);
    expect(a.task.title.value, '  Preserved  ');
    expect(a.occurrence.id.value, 'moved');
    expect(a.occurrence.scheduledDate.toString(), '2024-02-29');
    expect(a.occurrence.completedAtUtc, isNull);
  });
}
