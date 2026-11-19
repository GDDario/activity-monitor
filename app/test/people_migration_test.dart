import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';
import 'package:app/data/services/database/migrations/migration_0003_add_calendar_completion.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';

void main() {
  List<DatabaseMigration> v4() => [
    const Migration0001CreateCalendarTables(),
    Migration0002SeedCalendarExamples(
      CalendarSeeder(
        now: () => DateTime(2026, 11, 18),
        newId: () {
          return 'seed-${next++}';
        },
      ),
    ),
    const Migration0003AddCalendarCompletion(),
    const Migration0004CreateTaskTables(),
  ];
  test(
    'v4 upgrade preserves legacy identities names and multi-person membership',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      migrateDatabase(db, migrations: v4());
      final original = db
          .select('SELECT * FROM task_participants')
          .map((r) => Map<String, Object?>.from(r))
          .toList();
      db.execute('INSERT INTO calendar_participants(id,name) VALUES (?,?)', [
        'legacy',
        '😀' * 120,
      ]);
      migrateDatabase(db);
      expect(db.select('PRAGMA user_version').single.values.single, 7);
      expect(
        db
            .select(
              'SELECT name,role,revision FROM calendar_participants WHERE id=?',
              ['legacy'],
            )
            .single
            .values,
        ['😀' * 120, null, 0],
      );
      expect(
        db
            .select('SELECT * FROM task_participants')
            .map((r) => Map<String, Object?>.from(r))
            .toList(),
        original,
      );
      expect(db.select('SELECT * FROM person_categories'), isEmpty);
    },
  );
  test('failed additive migration rolls back metadata and version', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db, migrations: v4());
    db.execute('CREATE TABLE person_categories (unexpected TEXT)');
    expect(() => migrateDatabase(db), throwsA(isA<SqliteException>()));
    expect(db.select('PRAGMA user_version').single.values.single, 4);
    expect(
      db
          .select('PRAGMA table_info(calendar_participants)')
          .map((r) => r['name']),
      isNot(contains('role')),
    );
    expect(db.select('SELECT * FROM migrations').length, 4);
  });
}

int next = 0;
