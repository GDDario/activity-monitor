import 'package:sqlite3/sqlite3.dart';

import 'package:app/data/services/database/database_migration.dart';

class Migration0001CreateCalendarTables extends DatabaseMigration {
  const Migration0001CreateCalendarTables()
    : super(1, _createCalendarTables, name: '0001_create_calendar_tables');

  static void _createCalendarTables(Database db) {
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
}
