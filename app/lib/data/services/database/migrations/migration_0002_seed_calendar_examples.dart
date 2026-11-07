import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/calendar_seeder.dart';
import 'package:app/data/services/database/database_migration.dart';

class Migration0002SeedCalendarExamples extends DatabaseMigration {
  Migration0002SeedCalendarExamples(CalendarSeeder calendarSeeder)
    : super(
        2,
        _apply,
        name: '0002_seed_calendar_examples',
        seeder: calendarSeeder.run,
      );

  static void _apply(Database db) {}
}
