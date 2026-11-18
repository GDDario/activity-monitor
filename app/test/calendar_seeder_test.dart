import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations.dart';

void main() {
  test('seeds current month once and records migrations', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final seeder = CalendarSeeder(
      now: () => DateTime(2024, 2, 29),
      newId: const Uuid().v7,
    );
    migrateDatabase(db, calendarSeeder: seeder);
    final entries = db.select(
      'SELECT t.id, t.title, o.scheduled_date AS date, t.cadence FROM tasks t JOIN task_occurrences o ON o.task_id = t.id',
    );
    expect(entries, isNotEmpty);
    expect(
      entries.every((row) => (row['title'] as String).startsWith('Example: ')),
      isTrue,
    );
    expect(
      entries.every((row) => (row['date'] as String).startsWith('2024-02-')),
      isTrue,
    );
    expect(entries.any((row) => row['date'] == '2024-02-29'), isTrue);
    expect(entries.every((row) => (row['id'] as String)[14] == '7'), isTrue);
    expect(entries.map((row) => row['cadence']).toSet(), {
      'daily',
      'weekly',
      'one-time',
    });
    expect(db.select('SELECT * FROM task_participants'), isNotEmpty);
    expect(db.select('SELECT migration, batch FROM migrations').length, 4);
    migrateDatabase(
      db,
      calendarSeeder: CalendarSeeder(
        now: () => DateTime(2024, 3, 1),
        newId: const Uuid().v7,
      ),
    );
    expect(db.select('SELECT * FROM tasks').length, entries.length);
    expect(db.select('SELECT * FROM migrations').length, 4);
  });

  test('upgrades legacy version one and preserves records', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(
      db,
      migrations: [
        DatabaseMigration(1, (db) {
          db.execute(
            'CREATE TABLE calendar_entries (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL, date TEXT NOT NULL, cadence TEXT NOT NULL)',
          );
          db.execute(
            'CREATE TABLE calendar_participants (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL)',
          );
          db.execute(
            'CREATE TABLE calendar_entry_participants (entry_id TEXT NOT NULL, participant_id TEXT NOT NULL, PRIMARY KEY (entry_id, participant_id))',
          );
        }),
      ],
    );
    db.execute('DROP TABLE migrations');
    db.execute(
      "INSERT INTO calendar_entries VALUES ('existing', 'Saved', '2020-01-01', 'weekly')",
    );
    migrateDatabase(
      db,
      calendarSeeder: CalendarSeeder(
        now: () => DateTime(2025, 1, 1),
        newId: const Uuid().v7,
      ),
    );
    expect(
      db
          .select("SELECT title FROM tasks WHERE id = 'existing'")
          .single['title'],
      'Saved',
    );
    expect(db.select('PRAGMA user_version').single.values.single, 4);
    expect(db.select('SELECT migration, batch FROM migrations').length, 4);
  });

  test('rolls back seeding and history when the seeder fails', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    var count = 0;
    final seeder = CalendarSeeder(
      now: () => DateTime(2025, 4, 30),
      newId: () {
        if (++count == 3) throw StateError('seed failed');
        return const Uuid().v7();
      },
    );
    expect(() => migrateDatabase(db, calendarSeeder: seeder), throwsStateError);
    expect(db.select('PRAGMA user_version').single.values.single, 0);
    expect(
      db.select(
        "SELECT name FROM sqlite_master WHERE name IN ('migrations', 'calendar_entries')",
      ),
      isEmpty,
    );
    migrateDatabase(
      db,
      calendarSeeder: CalendarSeeder(
        now: () => DateTime(2025, 4, 30),
        newId: const Uuid().v7,
      ),
    );
    expect(db.select('SELECT * FROM migrations').length, 4);
  });

  test(
    'rejects inconsistent migration history without changing existing records',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      migrateDatabase(db);
      db.execute(
        'DELETE FROM migrations WHERE id = (SELECT MIN(id) FROM migrations)',
      );
      final entriesBefore = db.select('SELECT * FROM tasks').length;
      expect(() => migrateDatabase(db), throwsStateError);
      expect(db.select('SELECT * FROM tasks').length, entriesBefore);
    },
  );

  test('an injected migration seeder runs once after its table operation', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    var runs = 0;
    final migrations = [
      DatabaseMigration(
        1,
        (database) => database.execute('CREATE TABLE seeded (value TEXT)'),
        seeder: (database) {
          runs++;
          database.execute("INSERT INTO seeded VALUES ('example')");
        },
      ),
    ];
    migrateDatabase(db, migrations: migrations);
    migrateDatabase(db, migrations: migrations);
    expect(runs, 1);
    expect(db.select('SELECT value FROM seeded').single['value'], 'example');
  });

  test('does not recreate examples after the user deletes them', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db);
    db.execute('DELETE FROM tasks');
    migrateDatabase(db);
    expect(db.select('SELECT * FROM tasks'), isEmpty);
  });
}
