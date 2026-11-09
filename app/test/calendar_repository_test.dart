import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/calendar_database.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/repositories/calendar_repository.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/domain/value_objects/local_date.dart';
import 'package:app/domain/value_objects/local_date_range.dart';

import 'helpers/task_migration_fixture.dart';

void main() {
  test(
    'reads a fully migrated fixture after all legacy entry tables are removed',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      createLegacyTaskFixture(db);
      migrateDatabase(
        db,
        migrations: [
          ...historicalTaskMigrations(),
          const Migration0004CreateTaskTables(),
        ],
      );
      final result = await CalendarRepository(CalendarDatabase(() async => db))
          .load();
      expect(result.entries, hasLength(2));
      expect(
        result.entries.singleWhere((e) => e.id == 'done-id').isDone,
        isTrue,
      );
      expect(
        result.entries.singleWhere((e) => e.id == 'pending-id').title,
        '  Example: Café 🧘  ',
      );
    },
  );
  test('latest startup uses canonical task occurrences and preserves participant identities', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    expect(db.select('PRAGMA user_version').single.values.single, 4);
    db.execute('DELETE FROM tasks');
    db.execute('DELETE FROM calendar_participants');
    db.execute(
      "INSERT INTO tasks (id, title, start_date, cadence) VALUES ('task', 'Walk', '2024-02-29', 'daily')",
    );
    db.execute(
      "INSERT INTO task_occurrences (id, task_id, scheduled_date, effective_date, completed) VALUES ('e', 'task', '2024-02-29', '2024-03-01', 1)",
    );
    db.execute("INSERT INTO calendar_participants VALUES ('p', 'Lee')");
    db.execute("INSERT INTO task_participants VALUES ('task', 'p')");
    final result = await CalendarRepository(CalendarDatabase(() async => db))
        .load();
    final entry = result.entries.single;
    expect(entry.id, 'e');
    expect(entry.title, 'Walk');
    expect(entry.date, DateTime(2024, 3, 1));
    expect(entry.isDone, isTrue);
    expect(entry.taskAggregate!.task.id.value, 'task');
    expect(entry.taskAggregate!.occurrence.id.value, 'e');
    expect(entry.taskAggregate!.occurrence.completedAtUtc, isNull);
    expect(entry.participantIds, ['p']);
    expect(result.participants.single.name, 'Lee');
    expect(
      db.select(
        "SELECT * FROM sqlite_master WHERE name IN ('calendar_entries', 'calendar_entry_participants')",
      ),
      isEmpty,
    );
  });
  test('bounded reads use effective dates, hide tombstones and retain the complete participant catalog', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    db.execute('DELETE FROM tasks');
    db.execute('DELETE FROM calendar_participants');
    db.execute(
      "INSERT INTO calendar_participants VALUES ('person', 'Visible'), ('other', 'No cards in range')",
    );
    db.execute(
      "INSERT INTO tasks (id, title, start_date, cadence, notes, priority) VALUES ('task', 'Shared title', '2024-02-01', 'weekly', 'Notes', 'high')",
    );
    db.execute("INSERT INTO task_participants VALUES ('task', 'person')");
    db.execute("INSERT INTO tags VALUES ('tag', 'Café', 'café')");
    db.execute("INSERT INTO task_tags VALUES ('task', 'tag')");
    db.execute(
      "INSERT INTO task_subtasks (id, task_id, title, position) VALUES ('child', 'task', 'Checklist', 0)",
    );
    db.execute(
      "INSERT INTO task_occurrences (id, task_id, scheduled_date, effective_date, start_minute, end_minute) VALUES ('moved', 'task', '2024-02-28', '2024-03-01', 600, 660), ('outside', 'task', '2024-03-02', '2024-03-02', 600, 660)",
    );
    db.execute(
      "INSERT INTO task_occurrence_subtasks VALUES ('task', 'moved', 'child', 1)",
    );
    db.execute(
      "INSERT INTO task_occurrences (id, task_id, scheduled_date, effective_date, deleted_at_utc) VALUES ('deleted', 'task', '2024-02-27', '2024-03-01', '2024-03-01T12:00:00Z')",
    );
    final repository = CalendarRepository(CalendarDatabase(() async => db));
    final result = await repository.load(
      range: LocalDateRange(LocalDate(2024, 3, 1), LocalDate(2024, 3, 1)),
    );
    expect(result.entries.map((entry) => entry.id), ['moved']);
    expect(result.participants.map((participant) => participant.id).toSet(), {
      'person',
      'other',
    });
    final aggregate = result.entries.single.taskAggregate!;
    expect(aggregate.task.title.value, 'Shared title');
    expect(aggregate.task.notes, 'Notes');
    expect(aggregate.task.tags.single.name.value, 'Café');
    expect(aggregate.occurrence.timeWindow!.startMinute, 600);
    expect(aggregate.subtaskCompleted, 1);
    expect(aggregate.subtaskTotal, 1);
    expect(result.entries.single.participantIds, ['person']);
    final empty = await repository.load(
      range: LocalDateRange(LocalDate(2025, 1, 1), LocalDate(2025, 1, 1)),
    );
    expect(empty.entries, isEmpty);
    expect(empty.participants, hasLength(2));
  });

  test('orders each date by pending, local time, title and stable occurrence identity', () async {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    db.execute('DELETE FROM tasks');
    db.execute(
      "INSERT INTO tasks (id, title, start_date) VALUES ('a', 'Alpha', '2024-03-01'), ('b', 'Beta', '2024-03-01')",
    );
    db.execute(
      "INSERT INTO task_occurrences (id, task_id, scheduled_date, effective_date, start_minute, end_minute, completed) VALUES ('done', 'a', '2024-02-27', '2024-03-01', 60, 120, 1), ('untimed', 'a', '2024-02-28', '2024-03-01', NULL, NULL, 0), ('later', 'a', '2024-02-29', '2024-03-01', 600, 660, 0), ('beta', 'b', '2024-03-01', '2024-03-01', 60, 120, 0), ('alpha', 'a', '2024-03-01', '2024-03-01', 60, 120, 0)",
    );
    final result = await CalendarDatabase(() async => db).load();
    expect(result.entries.map((entry) => entry.id), [
      'alpha',
      'beta',
      'later',
      'untimed',
      'done',
    ]);
  });
}
