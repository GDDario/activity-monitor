import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/database_migration.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';

export 'package:app/data/services/database/database_migration.dart';

void migrateDatabase(
  Database db, {
  List<DatabaseMigration>? migrations,
  CalendarSeeder? calendarSeeder,
}) {
  final seeder =
      calendarSeeder ??
      CalendarSeeder(now: DateTime.now, newId: const Uuid().v7);
  final steps =
      migrations ??
      <DatabaseMigration>[
        const Migration0001CreateCalendarTables(),
        Migration0002SeedCalendarExamples(seeder),
      ];
  for (var i = 0; i < steps.length; i++) {
    if (steps[i].version != i + 1) {
      throw StateError(
        'Database migrations must be consecutive and start at 1',
      );
    }
  }
  db.execute('PRAGMA foreign_keys = ON');
  db.execute('BEGIN IMMEDIATE');
  try {
    final current =
        db.select('PRAGMA user_version').single.values.single as int;
    if (current > steps.length) {
      throw StateError('Unsupported database version');
    }
    final hasHistory = db
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'migrations'",
        )
        .isNotEmpty;
    if (!hasHistory && current > 1) {
      throw StateError('Database migration history is missing');
    }
    if (!hasHistory) {
      db.execute(
        'CREATE TABLE migrations (id INTEGER PRIMARY KEY AUTOINCREMENT, migration TEXT NOT NULL UNIQUE, batch INTEGER NOT NULL CHECK(batch > 0))',
      );
      if (current == 1) {
        db.execute('INSERT INTO migrations (migration, batch) VALUES (?, 1)', [
          steps.first.migrationName,
        ]);
      }
    }
    final history = db.select('SELECT migration FROM migrations ORDER BY id');
    if (history.length != current) {
      throw StateError('Database migration history does not match version');
    }
    for (var i = 0; i < current; i++) {
      if (history[i]['migration'] != steps[i].migrationName) {
        throw StateError('Database migration history does not match version');
      }
    }
    final batch =
        (db
                .select(
                  'SELECT COALESCE(MAX(batch), 0) AS last_batch FROM migrations',
                )
                .single['last_batch']
            as int) +
        1;
    for (final step in steps.skip(current)) {
      step.apply(db);
      step.seeder?.call(db);
      db.execute('INSERT INTO migrations (migration, batch) VALUES (?, ?)', [
        step.migrationName,
        batch,
      ]);
      db.execute('PRAGMA user_version = ${step.version}');
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
