import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';
import 'package:app/data/services/database/migrations/migration_0003_add_calendar_completion.dart';

List<DatabaseMigration> historicalTaskMigrations() {
  var next = 0;
  return [
    const Migration0001CreateCalendarTables(),
    Migration0002SeedCalendarExamples(
      CalendarSeeder(
        now: () => DateTime(2026, 11, 7),
        newId: () => 'example-${next++}',
      ),
    ),
    const Migration0003AddCalendarCompletion(),
  ];
}

void createLegacyTaskFixture(Database db, {int version = 3}) {
  if (version == 1) {
    const Migration0001CreateCalendarTables().apply(db);
    db.execute('PRAGMA user_version = 1');
  } else {
    migrateDatabase(
      db,
      migrations: historicalTaskMigrations().take(version).toList(),
    );
    db.execute('DELETE FROM calendar_entries');
    db.execute('DELETE FROM calendar_participants');
  }
  db.execute(
    "INSERT INTO calendar_participants VALUES ('person', '  Alex 👩🏽‍💻  ')",
  );
  db.execute(
    'INSERT INTO calendar_entries (id, title, date, cadence) VALUES (?, ?, ?, ?)',
    ['pending-id', '  Example: Café 🧘  ', '2024-02-29', 'daily'],
  );
  db.execute(
    "INSERT INTO calendar_entries (id, title, date, cadence) VALUES ('done-id', 'Weekly review', '2026-11-01', 'weekly')",
  );
  if (version == 3) {
    db.execute(
      "UPDATE calendar_entries SET completed = 1 WHERE id = 'done-id'",
    );
  }
  db.execute(
    "INSERT INTO calendar_entry_participants VALUES ('pending-id', 'person')",
  );
  db.execute(
    "INSERT INTO calendar_entry_participants VALUES ('done-id', 'person')",
  );
  db.execute('CREATE TABLE unrelated (value TEXT NOT NULL)');
  db.execute("INSERT INTO unrelated VALUES ('keep')");
}

/// Only execute/select are intercepted; every statement still uses real SQLite.
class InterceptedMigrationDatabase implements Database {
  InterceptedMigrationDatabase(this.database, this.afterStatement);
  final Database database;
  final void Function(String sql) afterStatement;

  @override
  void execute(String sql, [List<Object?> parameters = const []]) {
    database.execute(sql, parameters);
    afterStatement(sql);
  }

  @override
  ResultSet select(String sql, [List<Object?> parameters = const []]) {
    final result = database.select(sql, parameters);
    afterStatement(sql);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
