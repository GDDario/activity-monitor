import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/migrations/migration_0001_create_calendar_tables.dart';
import 'package:app/data/services/database/migrations/migration_0002_seed_calendar_examples.dart';
import 'package:app/data/services/database/migrations.dart';

void main() {
  test('numbered migrations preserve their persistent history identifiers', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    final seeder = CalendarSeeder(
      now: () => DateTime(2025, 1, 1),
      newId: const Uuid().v7,
    );
    migrateDatabase(
      db,
      migrations: [
        Migration0001CreateCalendarTables(),
        Migration0002SeedCalendarExamples(seeder),
      ],
    );
    expect(
      db
          .select('SELECT migration FROM migrations ORDER BY id')
          .map((row) => row['migration']),
      ['0001_create_calendar_tables', '0002_seed_calendar_examples'],
    );
  });
}
