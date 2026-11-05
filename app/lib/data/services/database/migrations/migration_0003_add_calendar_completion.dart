import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/database_migration.dart';

class Migration0003AddCalendarCompletion extends DatabaseMigration {
  const Migration0003AddCalendarCompletion()
    : super(3, _apply, name: '0003_add_calendar_completion');

  static void _apply(Database db) {
    db.execute(
      'ALTER TABLE calendar_entries ADD COLUMN completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1))',
    );
  }
}
