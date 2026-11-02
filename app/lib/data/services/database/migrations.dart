import 'package:sqlite3/sqlite3.dart';

class DatabaseMigration {
  const DatabaseMigration(this.version, this.apply);

  final int version;
  final void Function(Database database) apply;
}

final databaseMigrations = <DatabaseMigration>[
  DatabaseMigration(1, _createCalendarTables),
];

void migrateDatabase(Database db, {List<DatabaseMigration>? migrations}) {
  final steps = migrations ?? databaseMigrations;
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
    for (final step in steps.skip(current)) {
      step.apply(db);
      db.execute('PRAGMA user_version = ${step.version}');
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }
}

void _createCalendarTables(Database db) {
  db.execute(
    'CREATE TABLE calendar_entries (id TEXT PRIMARY KEY NOT NULL, title TEXT NOT NULL CHECK(length(trim(title)) > 0), date TEXT NOT NULL CHECK(length(date) = 10), cadence TEXT NOT NULL CHECK(cadence IN (\'daily\', \'weekly\', \'one-time\')))',
  );
  db.execute(
    'CREATE TABLE calendar_participants (id TEXT PRIMARY KEY NOT NULL, name TEXT NOT NULL CHECK(length(trim(name)) > 0))',
  );
  db.execute(
    'CREATE TABLE calendar_entry_participants (entry_id TEXT NOT NULL REFERENCES calendar_entries(id) ON DELETE CASCADE, participant_id TEXT NOT NULL REFERENCES calendar_participants(id) ON DELETE CASCADE, PRIMARY KEY(entry_id, participant_id))',
  );
}
