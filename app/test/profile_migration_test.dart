import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';
import 'package:app/data/services/database/migrations/migration_0003_add_calendar_completion.dart';
import 'package:app/data/services/database/migrations/migration_0004_create_task_tables.dart';
import 'package:app/data/services/database/migrations/migration_0005_add_people_metadata.dart';

void main() {
  var next = 0;
  List<DatabaseMigration> v5() => [
    const Migration0001CreateCalendarTables(),
    Migration0002SeedCalendarExamples(
      CalendarSeeder(
        now: () => DateTime(2026, 11, 18),
        newId: () => 'seed-${next++}',
      ),
    ),
    const Migration0003AddCalendarCompletion(),
    const Migration0004CreateTaskTables(),
    const Migration0005AddPeopleMetadata(),
  ];
  test(
    'v5 upgrade preserves tasks and companions without inventing a profile',
    () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      migrateDatabase(db, migrations: v5());
      db.execute(
        "INSERT INTO person_categories SELECT id,'work' FROM calendar_participants",
      );
      final before = {
        for (final table in [
          'tasks',
          'task_occurrences',
          'calendar_participants',
          'task_participants',
          'person_categories',
        ])
          table: db
              .select('SELECT * FROM $table')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
      };
      migrateDatabase(db);
      expect(db.select('PRAGMA user_version').single.values.single, 6);
      expect(db.select('SELECT * FROM local_profile'), isEmpty);
      for (final table in before.keys) {
        expect(
          db
              .select('SELECT * FROM $table')
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
          before[table],
        );
      }
      expect(db.select('PRAGMA foreign_key_check'), isEmpty);
    },
  );
  test('failed migration rolls back profile schema version and history', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    migrateDatabase(db, migrations: v5());
    db.execute('CREATE TABLE local_profile (existing TEXT)');
    expect(() => migrateDatabase(db), throwsA(isA<SqliteException>()));
    expect(db.select('PRAGMA user_version').single.values.single, 5);
    expect(db.select('SELECT * FROM migrations').length, 5);
    expect(
      db.select('PRAGMA table_info(local_profile)').map((r) => r['name']),
      ['existing'],
    );
  });
}
