import 'package:sqlite3/sqlite3.dart';
import 'package:app/data/services/database/database_migration.dart';

class Migration0005AddPeopleMetadata extends DatabaseMigration {
  const Migration0005AddPeopleMetadata()
    : super(5, _apply, name: '0005_add_people_metadata');
  static void _apply(Database db) {
    db.execute(
      "ALTER TABLE calendar_participants ADD COLUMN role TEXT CHECK(role IS NULL OR (length(trim(role)) <= 100))",
    );
    db.execute(
      'ALTER TABLE calendar_participants ADD COLUMN revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0)',
    );
    db.execute(
      "CREATE TABLE person_categories (participant_id TEXT NOT NULL REFERENCES calendar_participants(id) ON DELETE CASCADE, category TEXT NOT NULL CHECK(category IN ('work','household','creative','family')), PRIMARY KEY(participant_id,category))",
    );
  }
}
