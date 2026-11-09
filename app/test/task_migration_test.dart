import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';

import 'helpers/task_migration_fixture.dart';

List<DatabaseMigration> _steps() => [
  ...historicalTaskMigrations(),
  const Migration0004CreateTaskTables(),
];

Map<String, Object?> _snapshot(Database db) => {
  'version': db.select('PRAGMA user_version').single.values.single,
  'schema': db
      .select('SELECT * FROM sqlite_master ORDER BY name')
      .map((r) => Map<String, Object?>.from(r))
      .toList(),
  'rows': {
    for (final table in db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
    ))
      table['name'] as String: db
          .select('SELECT * FROM "${table['name']}" ORDER BY rowid')
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
  },
};

void main() {
  test('version 3 conversion preserves identity, bytes, completion, links and unknown times', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    createLegacyTaskFixture(db);
    final oldHistory = db
        .select('SELECT migration FROM migrations ORDER BY id')
        .map((row) => row['migration'])
        .toList();
    migrateDatabase(db, migrations: _steps());
    final tasks = db.select('SELECT * FROM tasks ORDER BY id');
    expect(tasks, hasLength(2));
    expect(tasks.last['id'], 'pending-id');
    expect(tasks.last['title'], '  Example: Café 🧘  ');
    expect(tasks.last['cadence'], 'daily');
    expect(tasks.last['start_date'], '2024-02-29');
    expect(tasks.first['title'], 'Weekly review');
    expect(tasks.first['cadence'], 'weekly');
    for (final task in tasks) {
      expect(task['recurrence_enabled'], 0);
      expect(task['priority'], 'low');
      expect(task['revision'], 0);
      expect(task['streak_enabled'], 0);
      for (final column in [
        'notes',
        'rule_effective_date',
        'start_minute',
        'end_minute',
        'reminder_minutes_before',
        'day_period',
        'created_at_utc',
        'updated_at_utc',
      ]) {
        expect(task[column], isNull, reason: column);
      }
    }
    final occurrences = db.select('SELECT * FROM task_occurrences ORDER BY id');
    expect(occurrences, hasLength(2));
    expect(occurrences.first['completed'], 1);
    expect(occurrences.last['completed'], 0);
    for (final occurrence in occurrences) {
      expect(occurrence['task_id'], occurrence['id']);
      expect(occurrence['scheduled_date'], occurrence['effective_date']);
      expect(occurrence['completed_at_utc'], isNull);
      expect(occurrence['deleted_at_utc'], isNull);
      expect(occurrence['start_minute'], isNull);
      expect(occurrence['end_minute'], isNull);
      expect(occurrence['reminder_minutes_before'], isNull);
      expect(occurrence['is_schedule_exception'], 0);
      expect(occurrence['revision'], 0);
    }
    expect(occurrences.first['scheduled_date'], '2026-11-01');
    expect(occurrences.last['scheduled_date'], '2024-02-29');
    expect(
      db
          .select('SELECT * FROM task_participants ORDER BY task_id')
          .map((r) => r.values.toList()),
      [
        ['done-id', 'person'],
        ['pending-id', 'person'],
      ],
    );
    expect(
      db.select('SELECT * FROM calendar_participants').single.values.toList(),
      ['person', '  Alex 👩🏽‍💻  '],
    );
    for (final table in [
      'task_weekdays',
      'task_subtasks',
      'task_occurrence_subtasks',
      'task_tags',
      'tags',
      'task_schedule_history',
    ]) {
      expect(db.select('SELECT * FROM $table'), isEmpty);
    }
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name IN ('calendar_entries', 'calendar_entry_participants')",
      ),
      isEmpty,
    );
    expect(db.select('SELECT * FROM unrelated').single['value'], 'keep');
    expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    expect(db.select('PRAGMA user_version').single.values.single, 4);
    expect(
      db
          .select('SELECT migration FROM migrations ORDER BY id')
          .map((r) => r['migration']),
      [...oldHistory, '0004_create_task_tables'],
    );
    final migrated = _snapshot(db);
    migrateDatabase(db, migrations: _steps());
    expect(_snapshot(db), migrated);
  });

  for (final version in [0, 1, 2, 3]) {
    test(
      'upgrades version $version without reseeding or repeating legacy entries',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.close);
        if (version > 0) createLegacyTaskFixture(db, version: version);
        migrateDatabase(db, migrations: _steps());
        // Version 1 has not yet run its once-only example seeder.
        final expectedCount = switch (version) {
          0 => 4,
          1 => 6,
          _ => 2,
        };
        expect(db.select('SELECT * FROM tasks'), hasLength(expectedCount));
        expect(
          db.select('SELECT * FROM task_occurrences'),
          hasLength(expectedCount),
        );
        expect(
          db.select('SELECT * FROM tasks WHERE recurrence_enabled <> 0'),
          isEmpty,
        );
        expect(db.select('SELECT * FROM migrations'), hasLength(4));
        if (version == 1) {
          expect(
            db
                .select('SELECT migration FROM migrations ORDER BY id')
                .first['migration'],
            '0001_create_calendar_tables',
          );
        }
        migrateDatabase(db, migrations: _steps());
        expect(db.select('SELECT * FROM tasks'), hasLength(expectedCount));
      },
    );

    for (final stage in [
      'CREATE TABLE tasks',
      'INSERT INTO tasks',
      'INSERT INTO task_occurrences',
      'INSERT INTO task_participants',
      'PRAGMA foreign_key_check',
      'DROP TABLE calendar_entry_participants',
      'DROP TABLE calendar_entries',
    ]) {
      test(
        'version $version failure after $stage rolls back schema, records, history and version',
        () {
          final db = sqlite3.openInMemory();
          addTearDown(db.close);
          if (version > 0) createLegacyTaskFixture(db, version: version);
          final original = _snapshot(db);
          var injected = false;
          final intercepted = InterceptedMigrationDatabase(db, (sql) {
            if (sql.startsWith(stage)) {
              injected = true;
              throw StateError('Injected SQLite migration stage failure');
            }
          });
          expect(
            () => migrateDatabase(intercepted, migrations: _steps()),
            throwsStateError,
          );
          expect(injected, isTrue);
          expect(_snapshot(db), original);
        },
      );
    }
  }

  for (final invalidId in ['', 'bad\u0000id']) {
    test('unrepresentable legacy identity aborts safely $invalidId', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      createLegacyTaskFixture(db);
      db.execute(
        'INSERT INTO calendar_entries (id, title, date, cadence) VALUES (?, ?, ?, ?)',
        [invalidId, 'Unrepresentable', '2026-11-07', 'one-time'],
      );
      final original = _snapshot(db);
      expect(() => migrateDatabase(db, migrations: _steps()), throwsStateError);
      expect(_snapshot(db), original);
    });
  }

  for (final invalid in <Map<String, Object?>>[
    {'title': List.filled(201, 'a').join()},
    {'title': '\u2003'},
    {'title': 'a\u0000b'},
    {'date': '2026-02-30'},
    {'date': '0000-01-01'},
    {'date': '2026-xx-07'},
  ]) {
    test(
      'unrepresentable legacy values abort without trimming or dropping records $invalid',
      () {
        final db = sqlite3.openInMemory();
        addTearDown(db.close);
        createLegacyTaskFixture(db);
        db.execute(
          'UPDATE calendar_entries SET ${invalid.keys.single} = ? WHERE id = ?',
          [invalid.values.single, 'pending-id'],
        );
        final original = _snapshot(db);
        expect(
          () => migrateDatabase(db, migrations: _steps()),
          throwsStateError,
        );
        expect(_snapshot(db), original);
      },
    );
  }

  for (final corruption in [
    "UPDATE tasks SET title = 'Changed' WHERE id = 'pending-id'",
    "DELETE FROM task_occurrences WHERE id = 'pending-id'",
    "DELETE FROM task_participants WHERE task_id = 'pending-id'",
  ]) {
    test('preservation comparisons detect $corruption before legacy drops', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      createLegacyTaskFixture(db);
      final original = _snapshot(db);
      final intercepted = InterceptedMigrationDatabase(db, (sql) {
        if (sql.startsWith('INSERT INTO task_participants')) {
          db.execute(corruption);
        }
      });
      expect(
        () => migrateDatabase(intercepted, migrations: _steps()),
        throwsStateError,
      );
      expect(_snapshot(db), original);
    });
  }

  test(
    'preexisting foreign-key corruption aborts before destructive drops',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      createLegacyTaskFixture(db);
      db.execute('PRAGMA foreign_keys = OFF');
      db.execute(
        'CREATE TABLE corrupt (task_id TEXT REFERENCES calendar_participants(id))',
      );
      db.execute("INSERT INTO corrupt VALUES ('missing')");
      final original = _snapshot(db);
      expect(() => migrateDatabase(db, migrations: _steps()), throwsStateError);
      expect(_snapshot(db), original);
    },
  );

  test('file-backed upgrade remains canonical and unchanged after reopening', () {
    final directory = Directory('../.scratches/task-migration-test');
    directory.createSync(recursive: true);
    final file = File(
      '${directory.path}/upgrade-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    var db = sqlite3.open(file.path);
    createLegacyTaskFixture(db);
    migrateDatabase(db, migrations: _steps());
    final expected = _snapshot(db);
    db.close();
    db = sqlite3.open(file.path);
    addTearDown(db.close);
    migrateDatabase(db, migrations: _steps());
    expect(_snapshot(db), expected);
  });
}
