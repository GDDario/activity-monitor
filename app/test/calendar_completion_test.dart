import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'package:app/data/services/calendar_database.dart';
import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';

void main() {
  test(
    'upgrades existing entries to pending and constrains completion status',
    () async {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);
      migrateDatabase(
        db,
        migrations: [
          const Migration0001CreateCalendarTables(),
          Migration0002SeedCalendarExamples(
            CalendarSeeder(
              now: () => DateTime(2024, 1, 1),
              newId: const Uuid().v7,
            ),
          ),
        ],
      );
      db.execute(
        "INSERT INTO calendar_entries (id, title, date, cadence) VALUES ('old', 'Existing', '2024-01-01', 'daily')",
      );
      migrateDatabase(db);
      expect(
        db
            .select("SELECT completed FROM calendar_entries WHERE id = 'old'")
            .single['completed'],
        0,
      );
      db.execute("UPDATE calendar_entries SET completed = 1 WHERE id = 'old'");
      expect(
        () => db.execute(
          "UPDATE calendar_entries SET completed = 2 WHERE id = 'old'",
        ),
        throwsA(isA<SqliteException>()),
      );
      final data = await CalendarDatabase(() async => db).load();
      expect(
        data.entries.singleWhere((entry) => entry.id == 'old').isDone,
        isTrue,
      );
    },
  );
}
